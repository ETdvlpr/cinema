from datetime import datetime

from cinema_pipeline import config
from cinema_pipeline.config import Cinema
from cinema_pipeline.publish import build_schedules
from cinema_pipeline.scrape import parse_channel_page
from cinema_pipeline.store import save_store

PAGE = """
<div class="tgme_widget_message_wrap">
 <div class="tgme_widget_message" data-post="SomeCinema/101">
  <div class="tgme_widget_message_grouped_wrap">
   <a class="tgme_widget_message_photo_wrap" href="https://t.me/SomeCinema/101"
      style="width:800px;background-image:url('https://cdn1.telesco.pe/file/aaa.jpg')"></a>
   <a class="tgme_widget_message_photo_wrap" href="https://t.me/SomeCinema/102"
      style="width:800px;background-image:url('https://cdn1.telesco.pe/file/bbb.jpg')"></a>
  </div>
  <div class="tgme_widget_message_text">This week's<br>schedule</div>
  <a class="tgme_widget_message_date"><time datetime="2025-10-06T08:00:00+00:00"></time></a>
 </div>
</div>
<div class="tgme_widget_message_wrap">
 <div class="tgme_widget_message" data-post="SomeCinema/103">
  <div class="tgme_widget_message_text">Text only post</div>
  <a class="tgme_widget_message_date"><time datetime="2025-10-06T09:00:00+00:00"></time></a>
 </div>
</div>
"""


def test_parse_channel_page():
    images = parse_channel_page(PAGE, "somecinema")
    assert [(i.key, i.image_url) for i in images] == [
        ("101-0", "https://cdn1.telesco.pe/file/aaa.jpg"),
        ("101-1", "https://cdn1.telesco.pe/file/bbb.jpg"),
    ]
    assert images[0].caption == "This week's\nschedule"
    assert images[0].post_url == "https://t.me/somecinema/101"


def _showtime(day: str, time: str, title: str) -> dict:
    return {
        "date": day, "time": time, "film_title": title, "film_title_latin": title, "hall": None,
        "format": None, "language": None, "price_birr": None, "confidence": 0.9,
    }


def _record(post_id: int, posted_at: str, status: str, showtimes: list[dict]) -> dict:
    return {
        "post_id": post_id, "index": 0, "post_url": f"https://t.me/c/{post_id}", "posted_at": posted_at,
        "image": f"posters/c/{post_id}-0.jpg", "status": status, "showtimes": showtimes,
    }


def test_newer_post_overrides_dates(tmp_path, monkeypatch):
    monkeypatch.setattr(config, "STORE_DIR", tmp_path / "data")
    monkeypatch.setattr(config, "PUBLIC_DIR", tmp_path / "public")
    monkeypatch.setattr(config, "SCHEDULES_FILE", tmp_path / "public" / "schedules.json")

    save_store({
        "cinema_id": "c", "last_checked": None, "last_error": None,
        "posters": {
            "1-0": _record(1, "2025-10-01T08:00:00+00:00", "ok", [
                _showtime("2025-10-05", "20:00", "Old past"),
                _showtime("2025-10-07", "20:00", "Old A"),
                _showtime("2025-10-08", "20:00", "Old B"),
            ]),
            "2-0": _record(2, "2025-10-06T08:00:00+00:00", "ok", [_showtime("2025-10-07", "21:00", "New A")]),
            "3-0": _record(3, "2025-10-06T10:00:00+00:00", "not_schedule", []),
        },
    })
    doc = build_schedules([Cinema("c", "C", "c")], datetime(2025, 10, 6, 12, tzinfo=config.TZ))

    cinema = doc["cinemas"][0]
    assert [(s["date"], s["film_title"]) for s in cinema["showtimes"]] == [
        ("2025-10-07", "New A"),
        ("2025-10-08", "Old B"),
    ]
    assert cinema["latest_poster"]["post_url"] == "https://t.me/c/2"
    assert cinema["latest_schedule_posted_at"] == "2025-10-06T08:00:00+00:00"


def test_maps_url_is_published_when_configured(tmp_path, monkeypatch):
    monkeypatch.setattr(config, "STORE_DIR", tmp_path / "data")
    monkeypatch.setattr(config, "PUBLIC_DIR", tmp_path / "public")
    monkeypatch.setattr(config, "SCHEDULES_FILE", tmp_path / "public" / "schedules.json")
    doc = build_schedules(
        [Cinema("a", "A", "a", maps="Laphto Mall, Addis Ababa"), Cinema("b", "B", "b")],
        datetime(2025, 10, 6, 12, tzinfo=config.TZ),
    )
    assert [c["maps_url"] for c in doc["cinemas"]] == [
        "https://www.google.com/maps/dir/?api=1&destination=Laphto+Mall%2C+Addis+Ababa",
        None,
    ]
