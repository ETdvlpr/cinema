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
from .extract import RawDateRange, RawExtraction, RawShowtime

MAX_RANGE_DAYS = 31
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
            showtimes = resolve_showtime(raw, posted_on, extraction.date_range)
        except Rejected as e:
            rejected.append({"reason": str(e), "raw": raw.model_dump()})
            continue
        for showtime in showtimes:
            slot = (showtime.date, showtime.time, (showtime.hall or "").lower(), showtime.film_title_latin.lower())
            if slot not in seen:
                seen.add(slot)
                accepted.append(showtime)
    return accepted, rejected


def resolve_showtime(raw: RawShowtime, posted_on: date, date_range: RawDateRange | None = None) -> list[Showtime]:
    """One raw entry usually yields one showtime; a "daily" entry under a date range yields one per day."""
    if raw.confidence < config.MIN_CONFIDENCE:
        raise Rejected(f"low confidence ({raw.confidence:.2f})")
    title = raw.film_title.strip()
    title_latin = raw.film_title_latin.strip() or title
    if not title_latin:
        raise Rejected("missing title")

    time = _resolve_time(raw)
    return [
        Showtime(
            date=day.isoformat(),
            time=time,
            film_title=title or title_latin,
            film_title_latin=title_latin,
            hall=_clean(raw.hall),
            format=_clean(raw.format),
            language=_clean(raw.language),
            price_birr=raw.price_birr if raw.price_birr and raw.price_birr > 0 else None,
            confidence=round(raw.confidence, 2),
        )
        for day in _resolve_dates(raw, posted_on, date_range)
    ]


def _resolve_dates(raw: RawShowtime, posted_on: date, date_range: RawDateRange | None) -> list[date]:
    if raw.month is not None and raw.day is not None:
        return [_resolve_single_date(raw, posted_on)]
    if date_range is None:
        raise Rejected("missing date")

    days = _resolve_range(date_range, posted_on)
    if raw.weekday is None:  # "daily" across the range
        return days
    matching = [d for d in days if WEEKDAYS[d.weekday()] == raw.weekday]
    if not matching:
        raise Rejected("weekday not in date range")
    if len(matching) > 1:
        raise Rejected("weekday occurs more than once in date range")
    return matching


def _resolve_single_date(raw: RawShowtime, posted_on: date) -> date:
    candidates = {
        d
        for calendar in _calendars(raw.date_calendar)
        for d in _date_candidates(calendar, raw.year, raw.month, raw.day, posted_on)
    }
    if not candidates:
        raise Rejected("invalid date")

    earliest, latest = _window(posted_on)
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


def _resolve_range(date_range: RawDateRange, posted_on: date) -> list[date]:
    """Resolves a printed range to its days, clipped to the plausible window."""
    earliest, latest = _window(posted_on)
    ranges = set()
    for calendar in _calendars(date_range.calendar):
        starts = _date_candidates(calendar, date_range.year, date_range.start_month, date_range.start_day, posted_on)
        ends = _date_candidates(calendar, date_range.year, date_range.end_month, date_range.end_day, posted_on)
        ranges |= {
            (start, end)
            for start in starts
            for end in ends
            if 0 <= (end - start).days <= MAX_RANGE_DAYS and start <= latest and end >= earliest
        }
    if not ranges:
        raise Rejected("date range invalid or outside plausible window")
    if len(ranges) > 1:
        raise Rejected("ambiguous date range")
    start, end = ranges.pop()
    days = (start + timedelta(days=i) for i in range((end - start).days + 1))
    return [d for d in days if earliest <= d <= latest]


def _calendars(calendar: str) -> list[str]:
    return ["gregorian", "ethiopian"] if calendar == "unknown" else [calendar]


def _date_candidates(calendar: str, year: int | None, month: int, day: int, posted_on: date) -> set[date]:
    """Every valid Gregorian date the printed values could mean, trying adjacent years if none is printed."""
    if calendar == "gregorian":
        base_year, convert = posted_on.year, date
    else:
        base_year, convert = gregorian_to_ethiopian(posted_on)[0], ethiopian_to_gregorian
    candidates = set()
    for y in [year] if year else [base_year - 1, base_year, base_year + 1]:
        try:
            candidates.add(convert(y, month, day))
        except ValueError:
            pass
    return candidates


def _window(posted_on: date) -> tuple[date, date]:
    return (
        posted_on - timedelta(days=config.LOOKBEHIND_DAYS),
        posted_on + timedelta(days=config.LOOKAHEAD_DAYS),
    )


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
