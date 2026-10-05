"""Vision-model extraction of showtimes from a poster image.

The model only transcribes. It reports which calendar/clock each value uses, and
all conversion and sanity checks happen in validate.py. To switch providers,
replace `_call_model` and keep its contract: return (JSON text, model name), and raise
ModelsUnavailable for quota/overload problems that should simply be retried later.
"""

from __future__ import annotations

import logging
import time
from datetime import date
from typing import Literal

from pydantic import BaseModel, Field

from .config import Settings
from .ethiopian import MONTH_NAMES, format_ethiopian

log = logging.getLogger(__name__)


class ModelsUnavailable(Exception):
    """Every configured model is over quota or overloaded. Not the image's fault; retry later."""


# Note: no field defaults. Gemini's response_schema rejects them.


class RawShowtime(BaseModel):
    film_title: str = Field(description="Film title exactly as printed (any script).")
    film_title_latin: str = Field(description="Title in Latin script: the English title if printed, otherwise a transliteration.")
    date_calendar: Literal["gregorian", "ethiopian", "unknown"] = Field(
        description="Calendar of the printed date. 'unknown' if only bare numbers are printed and the calendar cannot be told."
    )
    year: int | None = Field(description="Year as printed, or null if not printed.")
    month: int | None = Field(description="Month number in the stated calendar (Ethiopian: 1=Meskerem ... 13=Pagume).")
    day: int | None = Field(description="Day of month as printed.")
    weekday: Literal["monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday"] | None = Field(
        description="Weekday if printed, in English; otherwise null."
    )
    time_clock: Literal["ethiopian", "western"] = Field(description="Clock system of the printed time.")
    hour: int = Field(description="Hour exactly as printed. Do not convert.")
    minute: int = Field(description="Minute as printed (0 if not printed).")
    period: Literal["am", "pm", "day", "night", "unknown"] = Field(
        description="am/pm for western times; day/night for Ethiopian times; unknown if not indicated."
    )
    hall: str | None = Field(description="Hall/screen name or number, if printed.")
    format: str | None = Field(description="Screening format such as 2D, 3D, IMAX, if printed.")
    language: str | None = Field(description="Language or subtitles, if printed.")
    price_birr: float | None = Field(description="Ticket price in birr, if printed.")
    confidence: float = Field(description="0 to 1: how sure you are this entry is read correctly.")


class RawExtraction(BaseModel):
    is_schedule: bool = Field(description="True only if the image lists screenings with dates/times.")
    showtimes: list[RawShowtime]
    notes: str | None = Field(description="Anything unusual or hard to read, briefly.")


PROMPT = """\
This image was posted by {cinema_name}, a cinema in Ethiopia, on {posted_on} \
(Ethiopian calendar: {posted_on_ethiopian}).
{caption_block}
Decide whether the image is a showtime schedule. Trailers, promos, single-film ads \
without times, food menus, etc. are not: return is_schedule=false and no showtimes.

If it is a schedule, return one entry per screening (one film, one date, one time). \
If a date range or "daily" is printed, expand it into one entry per date, but only when \
the dates are explicit.

Rules:
- Transcribe numbers exactly as printed. NEVER convert between Ethiopian and western \
time or calendar. Report which system each value uses and we convert it.
- Ethiopian clock (e.g. "3 ሰዓት", "ከምሽቱ 2:30"): time_clock="ethiopian", the printed hour, \
and period="day" for ጠዋት/ከሰዓት/ከቀኑ (morning/afternoon), "night" for ምሽት/ማታ/ለሊት \
(evening/night), "unknown" if not stated.
- Western clock (e.g. "8:30 PM", "20:30"): time_clock="western", period am/pm if printed, \
else unknown.
- Ethiopian month names: {month_names} (and their Amharic forms). Use date_calendar="ethiopian" \
with month numbers 1-13 for these.
- If a value is not printed, use null. Do not guess.
"""


def build_prompt(cinema_name: str, posted_on: date, caption: str) -> str:
    caption_block = f"\nPost caption (may help):\n\"\"\"\n{caption[:1500]}\n\"\"\"\n" if caption.strip() else ""
    return PROMPT.format(
        cinema_name=cinema_name,
        posted_on=posted_on.strftime("%A %d %B %Y"),
        posted_on_ethiopian=format_ethiopian(posted_on),
        caption_block=caption_block,
        month_names=", ".join(f"{i}={name}" for i, name in enumerate(MONTH_NAMES, start=1)),
    )


_last_call = 0.0
# Models that hit their quota (or don't exist) during this run; skipped for the rest of it.
_exhausted_models: set[str] = set()


def all_models_exhausted(settings: Settings) -> bool:
    return all(m in _exhausted_models for m in settings.gemini_models)


def extract_schedule(
    image: bytes,
    mime_type: str,
    *,
    cinema_name: str,
    posted_on: date,
    caption: str,
    settings: Settings,
) -> tuple[RawExtraction, str]:
    """Returns the extraction and the name of the model that produced it."""
    global _last_call
    wait = settings.min_seconds_between_calls - (time.monotonic() - _last_call)
    if wait > 0:
        time.sleep(wait)
    try:
        text, model = _call_model(image, mime_type, build_prompt(cinema_name, posted_on, caption), settings)
    finally:
        _last_call = time.monotonic()
    return RawExtraction.model_validate_json(text), model


def _call_model(image: bytes, mime_type: str, prompt: str, settings: Settings) -> tuple[str, str]:
    from google import genai
    from google.genai import errors, types

    if not settings.gemini_api_key:
        raise RuntimeError("GEMINI_API_KEY is not set")
    client = genai.Client(api_key=settings.gemini_api_key)
    contents = [types.Part.from_bytes(data=image, mime_type=mime_type), prompt]
    config = types.GenerateContentConfig(
        response_mime_type="application/json",
        response_schema=RawExtraction,
        temperature=0,
    )

    last_error: Exception | None = None
    for model in settings.gemini_models:
        if model in _exhausted_models:
            continue
        try:
            response = client.models.generate_content(model=model, contents=contents, config=config)
        except errors.APIError as e:
            last_error = e
            if e.code in (404, 429):  # unknown model / quota used up: skip it for the rest of the run
                log.warning("%s unavailable for this run (%s %s)", model, e.code, e.status)
                _exhausted_models.add(model)
                continue
            if e.code in (500, 502, 503, 504):  # overloaded: try the next model for this image
                log.warning("%s overloaded (%s), trying next model", model, e.code)
                continue
            raise
        if not response.text:
            raise RuntimeError(f"{model} returned an empty response")
        return response.text, model
    raise ModelsUnavailable(f"all models over quota or overloaded; last error: {last_error}")
