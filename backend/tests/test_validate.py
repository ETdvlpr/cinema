from datetime import date

import pytest

from cinema_pipeline.extract import RawDateRange, RawExtraction, RawShowtime
from cinema_pipeline.validate import Rejected, resolve_showtime, validate_extraction

POSTED_ON = date(2025, 10, 6)  # Monday, 26 Meskerem 2018


def raw(**overrides) -> RawShowtime:
    fields = dict(
        film_title="ፊልም", film_title_latin="Film", date_calendar="gregorian", year=None, month=10, day=8,
        weekday=None, time_clock="western", hour=8, minute=30, period="pm", hall=None, format="2D",
        language=None, price_birr=350, confidence=0.9,
    )
    return RawShowtime(**(fields | overrides))


def test_western_pm():
    s, = resolve_showtime(raw(), POSTED_ON)
    assert (s.date, s.time) == ("2025-10-08", "20:30")


def test_ethiopian_date_and_clock():
    # 28 Meskerem, ምሽት 2:30 -> 8 October, 20:30
    s, = resolve_showtime(
        raw(date_calendar="ethiopian", month=1, day=28, time_clock="ethiopian", hour=2, period="night"), POSTED_ON
    )
    assert (s.date, s.time) == ("2025-10-08", "20:30")


def test_ambiguous_time_rejected():
    with pytest.raises(Rejected, match="ambiguous time"):
        resolve_showtime(raw(hour=10, period="unknown"), POSTED_ON)


def test_unambiguous_without_period():
    # 8:00 could be 08:00 or 20:00, but 08:00 is before screening hours
    assert resolve_showtime(raw(hour=8, minute=0, period="unknown"), POSTED_ON)[0].time == "20:00"


def test_unknown_calendar_resolved_by_window():
    # 10/8 as Ethiopian would be in June 2026 -> outside window, so Gregorian wins
    assert resolve_showtime(raw(date_calendar="unknown"), POSTED_ON)[0].date == "2025-10-08"


def test_weekday_mismatch_rejected():
    with pytest.raises(Rejected, match="weekday"):
        resolve_showtime(raw(weekday="friday"), POSTED_ON)  # 8 Oct 2025 is a Wednesday


def test_far_future_rejected():
    with pytest.raises(Rejected, match="window"):
        resolve_showtime(raw(month=12, day=25), POSTED_ON)


def test_low_confidence_rejected():
    with pytest.raises(Rejected, match="confidence"):
        resolve_showtime(raw(confidence=0.3), POSTED_ON)


def test_year_rollover():
    s, = resolve_showtime(raw(month=1, day=2), date(2025, 12, 30))
    assert s.date == "2026-01-02"


def test_duplicates_dropped():
    extraction = RawExtraction(is_schedule=True, date_range=None, showtimes=[raw(), raw(), raw(confidence=0.1)], notes=None)
    accepted, rejected = validate_extraction(extraction, POSTED_ON)
    assert len(accepted) == 1
    assert len(rejected) == 1


# Alem-style poster: heading "ከመስከረም 25 - 28", rows by weekday, Ethiopian clock with no day/night.
ALEM_RANGE = RawDateRange(calendar="ethiopian", year=None, start_month=1, start_day=25, end_month=1, end_day=28)
ALEM_POSTED_ON = date(2026, 10, 4)


def alem_entry(weekday, hour, minute):
    return raw(date_calendar="ethiopian", month=None, day=None, weekday=weekday,
               time_clock="ethiopian", hour=hour, minute=minute, period="unknown")


def test_weekday_rows_under_date_range():
    extraction = RawExtraction(is_schedule=True, date_range=ALEM_RANGE, notes=None, showtimes=[
        alem_entry("monday", 9, 0),      # 9 ሰዓት: 15:00 (03:00 is too early)
        alem_entry("tuesday", 2, 20),    # 02:20/08:20 too early, so 20:20
        alem_entry("thursday", 12, 20),  # 18:20
        alem_entry("friday", 1, 10),     # Friday isn't in Meskerem 25-28 (Mon-Thu)
    ])
    accepted, rejected = validate_extraction(extraction, ALEM_POSTED_ON)
    assert [(s.date, s.time) for s in accepted] == [
        ("2026-10-05", "15:00"),
        ("2026-10-06", "20:20"),
        ("2026-10-08", "18:20"),
    ]
    assert [r["reason"] for r in rejected] == ["weekday not in date range"]


def test_daily_entry_expands_over_range():
    gregorian_range = RawDateRange(calendar="gregorian", year=2026, start_month=10, start_day=5, end_month=10, end_day=7)
    extraction = RawExtraction(is_schedule=True, date_range=gregorian_range, notes=None, showtimes=[
        raw(month=None, day=None, weekday=None),
    ])
    accepted, _ = validate_extraction(extraction, date(2026, 10, 4))
    assert [s.date for s in accepted] == ["2026-10-05", "2026-10-06", "2026-10-07"]


def test_runtime_mistaken_for_showtime_is_rejected():
    # "አስቂኝ / 1:40" is a 1h40 runtime; if the model reports it as a daytime showtime it's 07:40
    with pytest.raises(Rejected, match="screening hours"):
        resolve_showtime(alem_entry("monday", 1, 40).model_copy(update={"period": "day"}), ALEM_POSTED_ON, ALEM_RANGE)
