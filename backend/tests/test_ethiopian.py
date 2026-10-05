from datetime import date

import pytest

from cinema_pipeline.ethiopian import (
    ethiopian_hour_candidates,
    ethiopian_to_gregorian,
    gregorian_to_ethiopian,
    western_hour_candidates,
)


@pytest.mark.parametrize(
    ("eth", "greg"),
    [
        ((2017, 1, 1), date(2024, 9, 11)),  # Enkutatash after a Gregorian leap year
        ((2018, 1, 1), date(2025, 9, 11)),
        ((2016, 1, 1), date(2023, 9, 12)),  # 2015 E.C. was a leap year (Pagume 6)
        ((2015, 13, 6), date(2023, 9, 11)),
        ((2016, 4, 29), date(2024, 1, 8)),  # Ethiopian Christmas (Genna) in a Gregorian-leap year
        ((2017, 4, 29), date(2025, 1, 7)),
    ],
)
def test_calendar_round_trip(eth, greg):
    assert ethiopian_to_gregorian(*eth) == greg
    assert gregorian_to_ethiopian(greg) == eth


def test_every_day_round_trips():
    d = date(2020, 1, 1)
    while d < date(2032, 1, 1):
        assert ethiopian_to_gregorian(*gregorian_to_ethiopian(d)) == d
        d = d.fromordinal(d.toordinal() + 1)


def test_pagume_6_only_in_leap_years():
    ethiopian_to_gregorian(2015, 13, 6)
    with pytest.raises(ValueError):
        ethiopian_to_gregorian(2016, 13, 6)


@pytest.mark.parametrize(
    ("hour", "period", "expected"),
    [
        (3, "day", [9]),
        (12, "day", [18]),
        (2, "night", [20]),
        (6, "night", [0]),
        (4, "unknown", [10, 22]),
        (13, "day", []),
    ],
)
def test_ethiopian_clock(hour, period, expected):
    assert ethiopian_hour_candidates(hour, period) == expected


@pytest.mark.parametrize(
    ("hour", "period", "expected"),
    [
        (8, "pm", [20]),
        (12, "pm", [12]),
        (12, "am", [0]),
        (20, "unknown", [20]),
        (8, "unknown", [8, 20]),
    ],
)
def test_western_clock(hour, period, expected):
    assert western_hour_candidates(hour, period) == expected
