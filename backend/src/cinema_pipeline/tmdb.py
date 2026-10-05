"""Film details from TMDB (themoviedb.org).

Matching is deliberately strict: a wrong poster is worse than none. A result must have the
same title (ignoring case and punctuation) and a release date close to now, since cinemas
show current films. Anything else is "none", and film_overrides.yaml can pin or block a match.

Required attribution (TMDB terms): "This product uses the TMDB API but is not endorsed or
certified by TMDB."
"""

from __future__ import annotations

from datetime import date, timedelta

import httpx

from .films_key import film_key

API = "https://api.themoviedb.org/3"

# Cinemas in Addis show films within months of their release.
RELEASED_WITHIN = timedelta(days=400)
RELEASING_WITHIN = timedelta(days=90)


class TmdbClient:
    def __init__(self, api_key: str, http: httpx.Client):
        self._http = http
        # v4 "API Read Access Token" (a JWT) goes in a header; a v3 "API Key" goes in the query.
        if api_key.startswith("eyJ"):
            self._headers = {"Authorization": f"Bearer {api_key}"}
            self._params = {}
        else:
            self._headers = {}
            self._params = {"api_key": api_key}

    def _get(self, path: str, **params) -> dict:
        resp = self._http.get(f"{API}{path}", params={**self._params, **params}, headers=self._headers, timeout=20)
        resp.raise_for_status()
        return resp.json()

    def find(self, title: str, today: date) -> int | None:
        """TMDB id of the current film with exactly this title, or None."""
        results = self._get("/search/movie", query=title, include_adult="false", language="en-US")["results"]
        key = film_key(title)
        candidates = []
        for r in results:
            if key not in (film_key(r.get("title") or ""), film_key(r.get("original_title") or "")):
                continue
            try:
                released = date.fromisoformat(r.get("release_date") or "")
            except ValueError:
                continue
            if today - RELEASED_WITHIN <= released <= today + RELEASING_WITHIN:
                candidates.append(r)
        if not candidates:
            return None
        return max(candidates, key=lambda r: r.get("popularity") or 0)["id"]

    def details(self, tmdb_id: int) -> dict:
        d = self._get(f"/movie/{tmdb_id}", append_to_response="videos,release_dates", language="en-US")
        trailers = [
            v for v in d.get("videos", {}).get("results", [])
            if v.get("site") == "YouTube" and v.get("type") == "Trailer"
        ]
        trailers.sort(key=lambda v: (not v.get("official"), v.get("published_at") or ""))
        certification = next(
            (
                rd.get("certification")
                for country in d.get("release_dates", {}).get("results", [])
                if country.get("iso_3166_1") == "US"
                for rd in country.get("release_dates", [])
                if rd.get("certification")
            ),
            None,
        )
        return {
            "id": d["id"],
            "title": d.get("title"),
            "overview": d.get("overview") or None,
            "release_date": d.get("release_date") or None,
            "runtime": d.get("runtime") or None,
            "genres": [g["name"] for g in d.get("genres", [])],
            "rating": round(d["vote_average"], 1) if d.get("vote_count", 0) >= 20 else None,
            "certification": certification,
            "poster_path": d.get("poster_path"),
            "backdrop_path": d.get("backdrop_path"),
            "trailer_youtube_key": trailers[0]["key"] if trailers else None,
        }
