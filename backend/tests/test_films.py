import io
from datetime import datetime, timedelta
from pathlib import Path

import httpx
import pytest
from PIL import Image

from cinema_pipeline import config, films
from cinema_pipeline.films_key import film_key, representative_title
from cinema_pipeline.tmdb import TmdbClient

NOW = datetime(2026, 10, 6, 12, tzinfo=config.TZ)
ALEM_POSTER = (Path(__file__).parent / "fixtures" / "alem_schedule.jpg").read_bytes()  # 480x800

SEARCH = {
    "results": [
        {"id": 1, "title": "Runner", "original_title": "Runner", "release_date": "2026-08-15", "popularity": 40},
        {"id": 2, "title": "Runner", "original_title": "Runner", "release_date": "2014-03-01", "popularity": 90},
        {"id": 3, "title": "Runner Runner", "original_title": "Runner Runner", "release_date": "2026-09-01", "popularity": 99},
    ]
}
DETAILS = {
    "id": 1,
    "title": "Runner",
    "overview": "A courier races across the city.",
    "release_date": "2026-08-15",
    "runtime": 98,
    "genres": [{"name": "Action"}, {"name": "Thriller"}],
    "vote_average": 6.84,
    "vote_count": 120,
    "poster_path": "/runner.jpg",
    "backdrop_path": "/runner-bg.jpg",
    "videos": {
        "results": [
            {"site": "YouTube", "type": "Teaser", "key": "teaser", "official": True},
            {"site": "YouTube", "type": "Trailer", "key": "fanmade", "official": False},
            {"site": "YouTube", "type": "Trailer", "key": "official", "official": True},
        ]
    },
    "release_dates": {
        "results": [
            {"iso_3166_1": "GB", "release_dates": [{"certification": "15"}]},
            {"iso_3166_1": "US", "release_dates": [{"certification": ""}, {"certification": "PG-13"}]},
        ]
    },
}


def tmdb_http(requests: list[httpx.Request] | None = None, fail: bool = False) -> httpx.Client:
    def handler(request: httpx.Request) -> httpx.Response:
        if requests is not None:
            requests.append(request)
        if fail:
            return httpx.Response(500)
        if request.url.path == "/3/search/movie":
            query = request.url.params["query"]
            return httpx.Response(200, json=SEARCH if film_key(query) == "runner" else {"results": []})
        if request.url.path.startswith("/3/movie/"):
            return httpx.Response(200, json={**DETAILS, "id": int(request.url.path.rsplit("/", 1)[1])})
        return httpx.Response(404)

    return httpx.Client(transport=httpx.MockTransport(handler))


@pytest.fixture
def paths(tmp_path, monkeypatch):
    for name, value in {
        "PUBLIC_DIR": tmp_path / "public",
        "THUMBS_DIR": tmp_path / "public" / "films",
        "FILMS_FILE": tmp_path / "data" / "films.json",
        "FILM_OVERRIDES_FILE": tmp_path / "film_overrides.yaml",
    }.items():
        monkeypatch.setattr(config, name, value)
    return tmp_path


# --- TMDB client -------------------------------------------------------------


def test_find_requires_exact_title_and_recent_release():
    # id 2 is more popular but a 2014 film; id 3 is a different title.
    assert TmdbClient("key", tmdb_http()).find("RUNNER", NOW.date()) == 1


def test_find_returns_none_without_a_match():
    assert TmdbClient("key", tmdb_http()).find("Hulet Fit", NOW.date()) is None


def test_details_are_parsed():
    d = TmdbClient("key", tmdb_http()).details(1)
    assert d["genres"] == ["Action", "Thriller"]
    assert d["rating"] == 6.8
    assert d["certification"] == "PG-13"
    assert d["trailer_youtube_key"] == "official"


def test_auth_v3_key_vs_v4_token():
    requests = []
    TmdbClient("abc123", tmdb_http(requests)).find("Runner", NOW.date())
    TmdbClient("eyJhbGciOi.token", tmdb_http(requests)).find("Runner", NOW.date())
    assert requests[0].url.params["api_key"] == "abc123"
    assert "Authorization" not in requests[0].headers
    assert requests[1].headers["Authorization"] == "Bearer eyJhbGciOi.token"
    assert "api_key" not in requests[1].url.params


# --- enrichment rules -------------------------------------------------------


def test_enrich_matches_and_skips(paths):
    store = {}
    showing = {
        "runner": {"title": "RUNNER", "amharic": False},
        "huletfit": {"title": "Hulet Fit", "amharic": True},
        "verity": {"title": "VERITY", "amharic": False},
    }
    films.enrich(store, showing, NOW, "key", tmdb_http())
    assert store["runner"]["tmdb"]["status"] == "matched"
    assert store["huletfit"]["tmdb"]["status"] == "skipped_amharic"
    assert store["verity"]["tmdb"]["status"] == "none"

    entry = films.public_entry(store["runner"])
    assert entry["title"] == "Runner"
    assert entry["trailer_url"] == "https://www.youtube.com/watch?v=official"
    assert entry["tmdb_url"] == "https://www.themoviedb.org/movie/1"
    assert films.public_entry(store["verity"])["poster_path"] is None


def test_none_is_rechecked_only_after_a_week(paths):
    requests = []
    store = {}
    showing = {"verity": {"title": "VERITY", "amharic": False}}
    films.enrich(store, showing, NOW, "key", tmdb_http(requests))
    films.enrich(store, showing, NOW + timedelta(days=1), "key", tmdb_http(requests))
    assert len(requests) == 1
    films.enrich(store, showing, NOW + timedelta(days=8), "key", tmdb_http(requests))
    assert len(requests) == 2


def test_overrides_block_or_pin(paths):
    config.FILM_OVERRIDES_FILE.write_text('"VERITY": none\n"Hulet Fit": 42\n', encoding="utf-8")
    store = {}
    films.enrich(
        store,
        {"verity": {"title": "VERITY", "amharic": False}, "huletfit": {"title": "Hulet Fit", "amharic": True}},
        NOW,
        "key",
        tmdb_http(),
    )
    assert store["verity"]["tmdb"]["status"] == "blocked"
    assert store["huletfit"]["tmdb"]["status"] == "matched"  # pinned, even though it's Amharic
    assert store["huletfit"]["tmdb"]["id"] == 42


def test_tmdb_errors_are_recorded_not_raised(paths):
    store = {}
    films.enrich(store, {"runner": {"title": "RUNNER", "amharic": False}}, NOW, "key", tmdb_http(fail=True))
    assert store["runner"]["tmdb"]["status"] == "error"


def test_no_api_key_means_no_lookups(paths):
    store = {}
    films.enrich(store, {"runner": {"title": "RUNNER", "amharic": False}}, NOW, None, tmdb_http(fail=True))
    assert "tmdb" not in store["runner"]
    assert films.public_entry(store["runner"])["title"] == "RUNNER"


# --- thumbnails cropped from schedule posters ------------------------------


def test_crop_alem_thumbnail():
    # First film artwork on Alem's poster sits at roughly x 12-127, y 40-160 of 480x800.
    thumb = films.crop_thumbnail(ALEM_POSTER, [50, 25, 200, 265])
    assert thumb is not None
    with Image.open(io.BytesIO(thumb)) as img:
        assert 100 <= img.width <= 130 and 100 <= img.height <= 130


@pytest.mark.parametrize(
    "box",
    [
        None,
        [50, 25, 200],  # wrong length
        [200, 25, 50, 265],  # inverted
        [0, 0, 1000, 1000],  # the whole poster
        [50, 25, 60, 30],  # too small
        [50, 0, 100, 1000],  # a wide strip, not artwork
    ],
)
def test_bad_boxes_are_rejected(box):
    assert films.crop_thumbnail(ALEM_POSTER, box) is None


def test_newest_poster_thumbnail_wins(paths):
    store = {}
    films.offer_thumbnail(store, "Hulet Fit", b"old", "https://t.me/a/1", "2026-10-01T10:00:00+00:00")
    films.offer_thumbnail(store, "HULET FIT", b"new", "https://t.me/a/2", "2026-10-04T10:00:00+00:00")
    films.offer_thumbnail(store, "Hulet Fit", b"older", "https://t.me/a/0", "2026-09-20T10:00:00+00:00")
    assert store["huletfit"]["thumbnail"]["post_url"] == "https://t.me/a/2"
    assert (config.THUMBS_DIR / "huletfit.jpg").read_bytes() == b"new"


def test_prune_removes_old_films_and_thumbnails(paths):
    store = {}
    films.offer_thumbnail(store, "Old Film", b"x", "https://t.me/a/1", "2026-08-01T10:00:00+00:00")
    films.prune_films(store, NOW)
    assert store == {}
    assert not (config.THUMBS_DIR / "oldfilm.jpg").exists()


def test_representative_title():
    assert representative_title(["SPIDER MAN", "SPIDER-MAN", "Spider-Man"]) == "SPIDER-MAN"
