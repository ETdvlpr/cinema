from __future__ import annotations

import os
from dataclasses import dataclass
from pathlib import Path
from zoneinfo import ZoneInfo

import yaml

# All paths are relative to the backend directory (where the workflow runs the pipeline).
ROOT = Path(os.environ.get("CINEMA_ROOT", Path.cwd()))
CINEMAS_FILE = ROOT / "cinemas.yaml"
STORE_DIR = ROOT / "data" / "extractions"
PUBLIC_DIR = ROOT / "public"
POSTERS_DIR = PUBLIC_DIR / "posters"
SCHEDULES_FILE = PUBLIC_DIR / "schedules.json"
FILMS_FILE = ROOT / "data" / "films.json"
FILM_OVERRIDES_FILE = ROOT / "film_overrides.yaml"
THUMBS_DIR = PUBLIC_DIR / "films"

TZ = ZoneInfo("Africa/Addis_Ababa")

# --- Validation knobs -------------------------------------------------------
MIN_CONFIDENCE = 0.6
# A showtime must fall within [post date - LOOKBEHIND, post date + LOOKAHEAD].
LOOKBEHIND_DAYS = 1
LOOKAHEAD_DAYS = 14
# Plausible screening hours (24h, inclusive). Also used to resolve ambiguous
# times: "8:00" with no am/pm only resolves if exactly one reading fits here.
EARLIEST_SHOW_HOUR = 9
LATEST_SHOW_HOUR = 23

# --- Housekeeping -----------------------------------------------------------
RETENTION_DAYS = 30  # posters/extractions older than this are pruned
# Only posters this recent are sent to the model; older ones mostly list past showtimes
# and would waste the free-tier daily quota.
PROCESS_MAX_AGE_DAYS = 7
MAX_ATTEMPTS = 3  # extraction attempts per image before giving up (quota/overload errors don't count)
# Alert if a poster still hasn't been extracted this long after the first attempt.
ALERT_AFTER_HOURS = 24


@dataclass(frozen=True)
class Cinema:
    id: str
    name: str
    channel: str
    maps: str | None = None  # Google Maps search text that finds the venue, for directions


def load_cinemas(path: Path = CINEMAS_FILE) -> list[Cinema]:
    raw = yaml.safe_load(path.read_text(encoding="utf-8"))
    cinemas = [
        Cinema(
            id=c["id"],
            name=c["name"],
            channel=c["channel"],
            maps=c.get("maps"),
        )
        for c in raw["cinemas"]
    ]
    ids = [c.id for c in cinemas]
    if len(ids) != len(set(ids)):
        raise ValueError(f"Duplicate cinema ids in {path}")
    return cinemas


@dataclass(frozen=True)
class Settings:
    gemini_api_key: str | None
    gemini_models: list[str]  # tried in order; each has its own free-tier quota
    max_images_per_run: int
    min_seconds_between_calls: float
    tmdb_api_key: str | None

    @classmethod
    def from_env(cls) -> Settings:
        return cls(
            gemini_api_key=os.environ.get("GEMINI_API_KEY") or None,
            # Comma-separated. "-latest" aliases survive model retirements; pin specific models
            # if you prefer stability.
            gemini_models=[
                m.strip()
                for m in (os.environ.get("GEMINI_MODEL") or "gemini-flash-latest,gemini-flash-lite-latest").split(",")
                if m.strip()
            ],
            max_images_per_run=int(os.environ.get("MAX_IMAGES_PER_RUN") or 40),
            # Keeps us under free-tier requests-per-minute limits.
            min_seconds_between_calls=float(os.environ.get("MIN_SECONDS_BETWEEN_CALLS") or 7),
            # Optional: film posters and details from TMDB. Either a v3 API key or a v4 read token.
            tmdb_api_key=os.environ.get("TMDB_API_KEY") or None,
        )
