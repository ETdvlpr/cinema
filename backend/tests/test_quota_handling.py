from datetime import datetime, timedelta

import pytest
from google import genai
from google.genai import errors

from cinema_pipeline import config, extract, pipeline
from cinema_pipeline.config import Cinema, Settings
from cinema_pipeline.scrape import ChannelImage

SETTINGS = Settings(
    gemini_api_key="test", gemini_models=["primary", "fallback"], max_images_per_run=40, min_seconds_between_calls=0,
    tmdb_api_key=None,
)
OK_JSON = '{"is_schedule": false, "date_range": null, "showtimes": [], "films": [], "notes": null}'


@pytest.fixture(autouse=True)
def fresh_quota_state():
    extract._exhausted_models.clear()
    yield
    extract._exhausted_models.clear()


def fake_client(monkeypatch, responses: dict[str, list]):
    """Each model pops its next response: an int is raised as an API error with that code, a str is returned."""
    calls = []

    class Models:
        def generate_content(self, *, model, contents, config):
            calls.append(model)
            outcome = responses[model].pop(0)
            if isinstance(outcome, int):
                raise errors.APIError(outcome, {"error": {"code": outcome, "message": "x", "status": "X"}})
            return type("Resp", (), {"text": outcome})()

    monkeypatch.setattr(genai, "Client", lambda api_key: type("C", (), {"models": Models()})())
    return calls


def test_overloaded_model_falls_back(monkeypatch):
    calls = fake_client(monkeypatch, {"primary": [503, OK_JSON], "fallback": [OK_JSON]})
    assert extract._call_model(b"", "image/jpeg", "", SETTINGS)[1] == "fallback"
    # 503 is transient: primary is tried again next time
    assert extract._call_model(b"", "image/jpeg", "", SETTINGS)[1] == "primary"
    assert calls == ["primary", "fallback", "primary"]


def test_quota_exhausted_model_is_skipped_for_rest_of_run(monkeypatch):
    calls = fake_client(monkeypatch, {"primary": [429], "fallback": [OK_JSON, 429]})
    assert extract._call_model(b"", "image/jpeg", "", SETTINGS)[1] == "fallback"
    with pytest.raises(extract.ModelsUnavailable):
        extract._call_model(b"", "image/jpeg", "", SETTINGS)
    assert calls == ["primary", "fallback", "fallback"]
    assert extract.all_models_exhausted(SETTINGS)


def test_other_errors_propagate(monkeypatch):
    fake_client(monkeypatch, {"primary": [400]})
    with pytest.raises(errors.APIError):
        extract._call_model(b"", "image/jpeg", "", SETTINGS)


def _image(post_id: int, age: timedelta) -> ChannelImage:
    return ChannelImage("c", post_id, 0, f"https://img/{post_id}", datetime.now(config.TZ) - age, "")


def test_quota_errors_dont_use_attempts_and_stop_the_run(tmp_path, monkeypatch):
    for name in ("STORE_DIR", "PUBLIC_DIR", "POSTERS_DIR", "SCHEDULES_FILE", "FILMS_FILE", "THUMBS_DIR", "FILM_OVERRIDES_FILE"):
        monkeypatch.setattr(config, name, tmp_path / name)

    images = [_image(1, timedelta(days=3)), _image(2, timedelta(hours=1)), _image(3, timedelta(days=20))]
    monkeypatch.setattr(pipeline, "fetch_channel_images", lambda client, channel: images)
    monkeypatch.setattr(pipeline, "_save_poster", lambda data, cinema_id, key: f"posters/{key}.jpg")

    class FakeHttp:
        def __init__(self, **kw): pass
        def __enter__(self): return self
        def __exit__(self, *a): pass
        def get(self, url, **kw):
            return type("R", (), {"content": b"", "headers": {}, "raise_for_status": lambda self: None})()

    monkeypatch.setattr(pipeline.httpx, "Client", FakeHttp)

    processed = []

    def fake_extract(image, mime, *, settings, **kw):
        processed.append(len(processed))
        extract._exhausted_models.update(settings.gemini_models)
        raise extract.ModelsUnavailable("over quota")

    monkeypatch.setattr(pipeline, "extract_schedule", fake_extract)

    problems = pipeline.run(SETTINGS, [Cinema("c", "C", "c")])

    store = pipeline.load_store("c")
    # Only the newest image was attempted; the run stopped once every model was out of quota,
    # and the 20-day-old image was never queued.
    assert len(processed) == 1
    assert list(store["posters"]) == ["2-0"]
    assert store["posters"]["2-0"]["status"] == "error"
    assert store["posters"]["2-0"]["attempts"] == 0
    assert problems == []
