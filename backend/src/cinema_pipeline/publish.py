"""Builds public/schedules.json from the per-cinema stores."""

from __future__ import annotations

import json
from collections import defaultdict
from datetime import datetime

from . import config
from .config import Cinema
from .films_key import film_key, has_ethiopic, representative_title
from .store import load_store


def build_document(cinemas: list[Cinema], now: datetime) -> dict:
    today = now.astimezone(config.TZ).date().isoformat()
    return {
        "generated_at": now.isoformat(timespec="seconds"),
        "timezone": "Africa/Addis_Ababa",
        "cinemas": [_build_cinema(cinema, load_store(cinema.id), today) for cinema in cinemas],
    }


def showing_films(doc: dict) -> dict[str, dict]:
    """Films with upcoming showtimes: key -> {title, amharic}."""
    titles: dict[str, list[str]] = defaultdict(list)
    amharic: dict[str, bool] = defaultdict(bool)
    for cinema in doc["cinemas"]:
        for s in cinema["showtimes"]:
            key = film_key(s["film_title_latin"])
            if not key:
                continue
            titles[key].append(s["film_title_latin"])
            amharic[key] |= has_ethiopic(s["film_title"])
    return {key: {"title": representative_title(t), "amharic": amharic[key]} for key, t in titles.items()}


def write_schedules(doc: dict) -> None:
    config.PUBLIC_DIR.mkdir(parents=True, exist_ok=True)
    config.SCHEDULES_FILE.write_text(json.dumps(doc, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")


def build_schedules(cinemas: list[Cinema], now: datetime) -> dict:
    """Schedules only, without film details (used by tests)."""
    doc = build_document(cinemas, now)
    write_schedules(doc)
    return doc


def _build_cinema(cinema: Cinema, store: dict, today: str) -> dict:
    # Group album images by post, newest post first.
    posts: dict[int, list[dict]] = defaultdict(list)
    for record in store["posters"].values():
        posts[record["post_id"]].append(record)
    ordered = sorted(posts.values(), key=lambda recs: recs[0]["posted_at"], reverse=True)

    # A newer post that covers a date replaces whatever older posts said about that date
    # (cinemas often repost corrected schedules).
    showtimes: list[dict] = []
    claimed_dates: set[str] = set()
    for records in ordered:
        post_dates: set[str] = set()
        for record in sorted(records, key=lambda r: r["index"]):
            for showtime in record.get("showtimes", []):
                post_dates.add(showtime["date"])
                if showtime["date"] >= today and showtime["date"] not in claimed_dates:
                    showtimes.append({**showtime, "poster": record["image"], "post_url": record["post_url"]})
        claimed_dates |= post_dates
    showtimes.sort(key=lambda s: (s["date"], s["time"], s["film_title_latin"].lower()))

    # Fallback for the app: the newest poster that might be a schedule, even if extraction failed.
    latest_poster = next(
        (
            {"image": r["image"], "post_url": r["post_url"], "posted_at": r["posted_at"], "status": r["status"]}
            for records in ordered
            for r in sorted(records, key=lambda r: r["index"])
            if r["status"] != "not_schedule" and r.get("image")
        ),
        None,
    )
    latest_schedule_post = next(
        (records[0]["posted_at"] for records in ordered if any(r["status"] == "ok" for r in records)),
        None,
    )

    return {
        "id": cinema.id,
        "name": cinema.name,
        "channel_url": f"https://t.me/{cinema.channel}",
        "last_checked": store["last_checked"],
        "last_error": store["last_error"],
        "latest_schedule_posted_at": latest_schedule_post,
        "latest_poster": latest_poster,
        "showtimes": showtimes,
    }
