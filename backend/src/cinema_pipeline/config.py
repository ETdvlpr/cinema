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
MAX_ATTEMPTS = 3  # extraction attempts per image before giving up


@dataclass(frozen=True)
class Cinema:
    id: str
    name: str
    channel: str


def load_cinemas(path: Path = CINEMAS_FILE) -> list[Cinema]:
    raw = yaml.safe_load(path.read_text(encoding="utf-8"))
    cinemas = [Cinema(id=c["id"], name=c["name"], channel=c["channel"]) for c in raw["cinemas"]]
    ids = [c.id for c in cinemas]
    if len(ids) != len(set(ids)):
        raise ValueError(f"Duplicate cinema ids in {path}")
    return cinemas


@dataclass(frozen=True)
class Settings:
    gemini_api_key: str | None
    gemini_model: str
    max_images_per_run: int
    min_seconds_between_calls: float

    @classmethod
    def from_env(cls) -> Settings:
        return cls(
            gemini_api_key=os.environ.get("GEMINI_API_KEY") or None,
            # A "-latest" alias survives model retirements; pin a specific model if you prefer stability.
            gemini_model=os.environ.get("GEMINI_MODEL") or "gemini-flash-latest",
            max_images_per_run=int(os.environ.get("MAX_IMAGES_PER_RUN") or 40),
            # Keeps us under free-tier requests-per-minute limits.
            min_seconds_between_calls=float(os.environ.get("MIN_SECONDS_BETWEEN_CALLS") or 7),
        )
