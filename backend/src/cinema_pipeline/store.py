"""Per-cinema record of every poster we've seen, kept in data/extractions/<id>.json.

This is the pipeline's memory between runs (it's committed to the repo) and the
input for building schedules.json.

Poster statuses:
  ok            schedule extracted, at least one valid showtime
  unreadable    model says it's a schedule but nothing passed validation
  not_schedule  promo/trailer/etc.; its image is deleted
  error         download or model call failed; retried next run
  failed        still erroring after MAX_ATTEMPTS; left alone
  expired       still erroring when it aged out of PROCESS_MAX_AGE_DAYS; left alone
"""

from __future__ import annotations

import json
from datetime import datetime, timedelta

from . import config


def load_store(cinema_id: str) -> dict:
    path = config.STORE_DIR / f"{cinema_id}.json"
    if path.exists():
        return json.loads(path.read_text(encoding="utf-8"))
    return {"cinema_id": cinema_id, "last_checked": None, "last_error": None, "posters": {}}


def save_store(store: dict) -> None:
    config.STORE_DIR.mkdir(parents=True, exist_ok=True)
    path = config.STORE_DIR / f"{store['cinema_id']}.json"
    path.write_text(json.dumps(store, ensure_ascii=False, indent=1, sort_keys=True) + "\n", encoding="utf-8")


def prune_store(store: dict, now: datetime) -> None:
    cutoff = now - timedelta(days=config.RETENTION_DAYS)
    for key, record in list(store["posters"].items()):
        if datetime.fromisoformat(record["posted_at"]) < cutoff:
            delete_poster_image(record)
            del store["posters"][key]


def delete_poster_image(record: dict) -> None:
    if record.get("image"):
        (config.PUBLIC_DIR / record["image"]).unlink(missing_ok=True)
        record["image"] = None
