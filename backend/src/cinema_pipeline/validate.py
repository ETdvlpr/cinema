"""Turns raw model output into trustworthy showtimes, or rejects it with a reason.

Whenever a value has more than one plausible reading (unknown calendar, no am/pm),
we try every reading and accept only if exactly one survives the sanity checks.
Anything doubtful is dropped rather than published.
"""

from __future__ import annotations

from dataclasses import asdict, dataclass
from datetime import date, timedelta

from . import config
from .ethiopian import (
    ethiopian_hour_candidates,
    ethiopian_to_gregorian,
    gregorian_to_ethiopian,
    western_hour_candidates,
)
from .extract import RawExtraction, RawShowtime

WEEKDAYS = ["monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday"]


class Rejected(Exception):
    pass


@dataclass(frozen=True)
class Showtime:
    date: str  # YYYY-MM-DD, Gregorian, Addis Ababa local
    time: str  # HH:MM, 24h
    film_title: str
    film_title_latin: str
    hall: str | None
    format: str | None
    language: str | None
    price_birr: float | None
    confidence: float

    def to_dict(self) -> dict:
        return asdict(self)


def validate_extraction(extraction: RawExtraction, posted_on: date) -> tuple[list[Showtime], list[dict]]:
    accepted: list[Showtime] = []
    rejected: list[dict] = []
    seen: set[tuple] = set()
    for raw in extraction.showtimes:
        try:
            showtime = resolve_showtime(raw, posted_on)
        except Rejected as e:
            rejected.append({"reason": str(e), "raw": raw.model_dump()})
            continue
        slot = (showtime.date, showtime.time, (showtime.hall or "").lower(), showtime.film_title_latin.lower())
        if slot in seen:
            continue
        seen.add(slot)
        accepted.append(showtime)
    return accepted, rejected


def resolve_showtime(raw: RawShowtime, posted_on: date) -> Showtime:
    if raw.confidence < config.MIN_CONFIDENCE:
        raise Rejected(f"low confidence ({raw.confidence:.2f})")
    title = raw.film_title.strip()
    title_latin = raw.film_title_latin.strip() or title
    if not title_latin:
        raise Rejected("missing title")

    return Showtime(
        date=_resolve_date(raw, posted_on).isoformat(),
        time=_resolve_time(raw),
        film_title=title or title_latin,
        film_title_latin=title_latin,
        hall=_clean(raw.hall),
        format=_clean(raw.format),
        language=_clean(raw.language),
        price_birr=raw.price_birr if raw.price_birr and raw.price_birr > 0 else None,
        confidence=round(raw.confidence, 2),
    )


def _resolve_date(raw: RawShowtime, posted_on: date) -> date:
    if raw.month is None or raw.day is None:
        raise Rejected("missing date")

    calendars = ["gregorian", "ethiopian"] if raw.date_calendar == "unknown" else [raw.date_calendar]
    candidates: set[date] = set()
    for calendar in calendars:
        if calendar == "gregorian":
            base_year, convert = posted_on.year, date
        else:
            base_year, convert = gregorian_to_ethiopian(posted_on)[0], ethiopian_to_gregorian
        years = [raw.year] if raw.year else [base_year - 1, base_year, base_year + 1]
        for year in years:
            try:
                candidates.add(convert(year, raw.month, raw.day))
            except ValueError:
                pass
    if not candidates:
        raise Rejected("invalid date")

    earliest = posted_on - timedelta(days=config.LOOKBEHIND_DAYS)
    latest = posted_on + timedelta(days=config.LOOKAHEAD_DAYS)
    in_window = {d for d in candidates if earliest <= d <= latest}
    if not in_window:
        raise Rejected("date outside plausible window")

    if raw.weekday:
        matching = {d for d in in_window if WEEKDAYS[d.weekday()] == raw.weekday}
        if not matching:
            raise Rejected("weekday does not match date")
        in_window = matching

    if len(in_window) > 1:
        raise Rejected("ambiguous date")
    return in_window.pop()


def _resolve_time(raw: RawShowtime) -> str:
    if not 0 <= raw.minute <= 59:
        raise Rejected("invalid minute")
    if raw.time_clock == "ethiopian":
        hours = ethiopian_hour_candidates(raw.hour, raw.period)
    else:
        hours = western_hour_candidates(raw.hour, raw.period)
    if not hours:
        raise Rejected("invalid hour")

    plausible = [h for h in hours if config.EARLIEST_SHOW_HOUR <= h <= config.LATEST_SHOW_HOUR]
    if not plausible:
        raise Rejected("time outside screening hours")
    if len(plausible) > 1:
        raise Rejected("ambiguous time (no am/pm or day/night)")
    return f"{plausible[0]:02d}:{raw.minute:02d}"


def _clean(value: str | None) -> str | None:
    value = (value or "").strip()
    return value or None
