import re
from collections import Counter

_ETHIOPIC = re.compile(r"[ሀ-᎟ⶀ-⷟꬀-꬯]")


def film_key(title: str) -> str:
    """Identifies a film across posters and cinemas: "SPIDER-MAN: Brand New Day" == "spider man brand new day".

    Must match the app's Showtime.filmKey.
    """
    return re.sub(r"[^a-z0-9]", "", title.lower())


def has_ethiopic(text: str) -> bool:
    return bool(_ETHIOPIC.search(text))


def representative_title(titles: list[str]) -> str:
    """The most common spelling, voting case-insensitively."""
    counts = Counter(t.lower() for t in titles)
    best = counts.most_common(1)[0][0]
    return next(t for t in titles if t.lower() == best)
