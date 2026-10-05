"""Per-film details, kept in data/films.json and keyed by film_key().

Two sources:
  - TMDB, for films it knows (foreign releases). Amharic films are skipped: TMDB rarely has
    them, and a transliterated title would only produce false matches.
  - A thumbnail cropped from the cinema's own schedule poster, for every film whose artwork
    the vision model located. The newest poster wins.
"""

from __future__ import annotations

import io
import json
import logging
from datetime import datetime, timedelta

import httpx
import yaml
from PIL import Image

from . import config
from .films_key import film_key
from .tmdb import TmdbClient

log = logging.getLogger(__name__)

TMDB_IMAGE_BASE = "https://image.tmdb.org/t/p/"
RECHECK_NONE_AFTER = timedelta(days=7)  # TMDB may add a film after it opens here
RECHECK_ERROR_AFTER = timedelta(hours=6)
MAX_TMDB_LOOKUPS_PER_RUN = 40


# --- storage -----------------------------------------------------------------


def load_films() -> dict:
    if config.FILMS_FILE.exists():
        return json.loads(config.FILMS_FILE.read_text(encoding="utf-8"))
    return {}


def save_films(films: dict) -> None:
    config.FILMS_FILE.parent.mkdir(parents=True, exist_ok=True)
    config.FILMS_FILE.write_text(json.dumps(films, ensure_ascii=False, indent=1, sort_keys=True) + "\n", encoding="utf-8")


def load_overrides() -> dict[str, int | None]:
    """film_overrides.yaml: title -> TMDB id, or none to never use TMDB for it."""
    if not config.FILM_OVERRIDES_FILE.exists():
        return {}
    raw = yaml.safe_load(config.FILM_OVERRIDES_FILE.read_text(encoding="utf-8")) or {}
    return {film_key(str(title)): (None if value in (None, "none") else int(value)) for title, value in raw.items()}


def prune_films(films: dict, now: datetime) -> None:
    cutoff = now - timedelta(days=config.RETENTION_DAYS)
    for key, film in list(films.items()):
        if datetime.fromisoformat(film["last_seen"]) < cutoff:
            if film.get("thumbnail"):
                (config.PUBLIC_DIR / film["thumbnail"]["image"]).unlink(missing_ok=True)
            del films[key]


# --- thumbnails cropped from schedule posters --------------------------------


def crop_thumbnail(image: bytes, box_2d: list[int] | None) -> bytes | None:
    """Crops [ymin, xmin, ymax, xmax] (0-1000, Gemini's convention). None if the box looks wrong."""
    if not box_2d or len(box_2d) != 4:
        return None
    ymin, xmin, ymax, xmax = box_2d
    if not (0 <= ymin < ymax <= 1000 and 0 <= xmin < xmax <= 1000):
        return None
    with Image.open(io.BytesIO(image)) as img:
        img = img.convert("RGB")
        w, h = img.size
        left, top, right, bottom = (round(xmin * w / 1000), round(ymin * h / 1000), round(xmax * w / 1000), round(ymax * h / 1000))
        cw, ch = right - left, bottom - top
        # Film artwork: big enough to be useful, not most of the poster, roughly poster-shaped.
        if cw < 40 or ch < 40 or (cw * ch) > 0.35 * w * h or not 0.4 <= cw / ch <= 1.5:
            return None
        thumb = img.crop((left, top, right, bottom))
        thumb.thumbnail((400, 400))
        out = io.BytesIO()
        thumb.save(out, "JPEG", quality=85, optimize=True)
        return out.getvalue()


def offer_thumbnail(films: dict, title: str, image: bytes, post_url: str, posted_at: str) -> None:
    """Keeps the thumbnail from the newest poster for each film."""
    key = film_key(title)
    if not key:
        return
    film = films.setdefault(key, {"title": title, "first_seen": posted_at, "last_seen": posted_at})
    current = film.get("thumbnail")
    if current and current["posted_at"] >= posted_at:
        return
    path = config.THUMBS_DIR / f"{key}.jpg"
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(image)
    film["thumbnail"] = {
        "image": path.relative_to(config.PUBLIC_DIR).as_posix(),
        "post_url": post_url,
        "posted_at": posted_at,
    }


# --- TMDB --------------------------------------------------------------------


def enrich(films: dict, showing: dict[str, dict], now: datetime, api_key: str | None, http: httpx.Client) -> None:
    """Adds TMDB details for films currently showing. `showing`: key -> {title, amharic}."""
    overrides = load_overrides()
    client = TmdbClient(api_key, http) if api_key else None
    lookups = 0

    for key, info in showing.items():
        film = films.setdefault(key, {"first_seen": now.isoformat(timespec="seconds")})
        film["title"] = info["title"]
        film["last_seen"] = now.isoformat(timespec="seconds")

        if key in overrides and overrides[key] is None:
            film["tmdb"] = {"status": "blocked"}
            continue
        if info["amharic"] and key not in overrides:
            film["tmdb"] = {"status": "skipped_amharic"}
            continue
        if client is None or not _needs_lookup(film.get("tmdb"), overrides.get(key), now):
            continue
        if lookups >= MAX_TMDB_LOOKUPS_PER_RUN:
            break
        lookups += 1

        checked_at = now.isoformat(timespec="seconds")
        try:
            tmdb_id = overrides.get(key) or client.find(info["title"], now.date())
            if tmdb_id is None:
                film["tmdb"] = {"status": "none", "checked_at": checked_at}
                log.info("TMDB: no match for %r", info["title"])
            else:
                film["tmdb"] = {"status": "matched", "checked_at": checked_at, **client.details(tmdb_id)}
                log.info("TMDB: %r -> %s (%s)", info["title"], film["tmdb"]["title"], tmdb_id)
        except httpx.HTTPError as e:
            film["tmdb"] = {"status": "error", "checked_at": checked_at, "error": str(e)[:300]}
            log.warning("TMDB lookup failed for %r: %s", info["title"], e)


def _needs_lookup(tmdb: dict | None, override_id: int | None, now: datetime) -> bool:
    if tmdb is None or tmdb.get("status") in ("blocked", "skipped_amharic"):
        return True
    if override_id is not None and tmdb.get("id") != override_id:
        return True  # override added or changed since the last lookup
    checked = datetime.fromisoformat(tmdb["checked_at"]) if tmdb.get("checked_at") else None
    if tmdb["status"] == "none":
        return checked is None or now - checked > RECHECK_NONE_AFTER
    if tmdb["status"] == "error":
        return checked is None or now - checked > RECHECK_ERROR_AFTER
    return False


# --- published form ----------------------------------------------------------


def public_entry(film: dict) -> dict:
    tmdb = film.get("tmdb") or {}
    matched = tmdb.get("status") == "matched"
    return {
        "title": tmdb["title"] if matched and tmdb.get("title") else film.get("title"),
        "overview": tmdb.get("overview") if matched else None,
        "release_date": tmdb.get("release_date") if matched else None,
        "runtime": tmdb.get("runtime") if matched else None,
        "genres": tmdb.get("genres", []) if matched else [],
        "rating": tmdb.get("rating") if matched else None,
        "certification": tmdb.get("certification") if matched else None,
        "tmdb_id": tmdb.get("id") if matched else None,
        "tmdb_url": f"https://www.themoviedb.org/movie/{tmdb['id']}" if matched else None,
        "trailer_url": (
            f"https://www.youtube.com/watch?v={tmdb['trailer_youtube_key']}"
            if matched and tmdb.get("trailer_youtube_key")
            else None
        ),
        "poster_path": tmdb.get("poster_path") if matched else None,
        "backdrop_path": tmdb.get("backdrop_path") if matched else None,
        "thumbnail": film["thumbnail"]["image"] if film.get("thumbnail") else None,
    }
