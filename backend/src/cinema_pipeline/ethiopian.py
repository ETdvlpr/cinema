"""Ethiopian calendar and clock conversions.

These are done in code, never by the model: the model only reports what is
printed and which system it uses.
"""

from __future__ import annotations

from datetime import date

MONTH_NAMES = [
    "Meskerem", "Tikimt", "Hidar", "Tahsas", "Tir", "Yekatit", "Megabit",
    "Miyazya", "Ginbot", "Sene", "Hamle", "Nehase", "Pagume",
]

# Julian Day Number of 1 Meskerem, year 1 (Amete Mihret epoch).
_EPOCH_JDN = 1724221
# date.toordinal() + this = Julian Day Number
_ORDINAL_TO_JDN = 1721425


def is_leap_year(year: int) -> bool:
    return year % 4 == 3


def ethiopian_to_gregorian(year: int, month: int, day: int) -> date:
    if not 1 <= month <= 13:
        raise ValueError(f"Ethiopian month out of range: {month}")
    max_day = 30 if month <= 12 else (6 if is_leap_year(year) else 5)
    if not 1 <= day <= max_day:
        raise ValueError(f"Ethiopian day out of range: {year}-{month}-{day}")
    jdn = _EPOCH_JDN + 365 * (year - 1) + year // 4 + 30 * (month - 1) + day - 1
    return date.fromordinal(jdn - _ORDINAL_TO_JDN)


def gregorian_to_ethiopian(d: date) -> tuple[int, int, int]:
    year = d.year - 7
    new_year = ethiopian_to_gregorian(year, 1, 1)
    if d < new_year:
        year -= 1
        new_year = ethiopian_to_gregorian(year, 1, 1)
    day_of_year = (d - new_year).days
    return year, day_of_year // 30 + 1, day_of_year % 30 + 1


def format_ethiopian(d: date) -> str:
    year, month, day = gregorian_to_ethiopian(d)
    return f"{day} {MONTH_NAMES[month - 1]} {year}"


def ethiopian_hour_candidates(hour: int, period: str) -> list[int]:
    """Possible 24h hours for an Ethiopian-clock hour.

    The Ethiopian day starts at 06:00, so "1 ሰዓት" is 07:00 (day) or 19:00 (night),
    and "12 ሰዓት" is 18:00 (day) or 06:00 (night).
    """
    if not 1 <= hour <= 12:
        return []
    day = hour + 6
    night = (hour + 18) % 24
    if period == "day":
        return [day]
    if period == "night":
        return [night]
    return [day, night]


def western_hour_candidates(hour: int, period: str) -> list[int]:
    if hour == 24:
        hour = 0
    if not 0 <= hour <= 23:
        return []
    if hour > 12 or hour == 0:
        return [hour]
    if period == "am":
        return [0 if hour == 12 else hour]
    if period == "pm":
        return [12 if hour == 12 else hour + 12]
    return [12] if hour == 12 else [hour, hour + 12]

