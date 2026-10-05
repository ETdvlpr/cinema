# Addis Ababa cinema schedules

Showtimes for Addis Ababa cinemas, collected automatically from the posters they post on Telegram
and published as one JSON file.

**Live data:** https://etdvlpr.github.io/cinema/schedules.json (updated every 6 hours)

## Cinemas

| Cinema | Telegram |
|---|---|
| Alem Cinema | [@alem_cinema](https://t.me/alem_cinema) |
| Century Cinema | [@Century_Cinema](https://t.me/Century_Cinema) |
| GAST Cinema | [@GastCinema](https://t.me/GastCinema) |
| Laphto Chewata Cinema | [@chewatacinema](https://t.me/chewatacinema) |
| Garad Multi Cinema | [@garadmulticinema](https://t.me/garadmulticinema) |

To add a cinema, add its public channel to [`backend/cinemas.yaml`](backend/cinemas.yaml).

## How it works

```
Telegram public preview (t.me/s/<channel>)
  → GitHub Action, every 6 hours
  → Gemini reads each new poster
  → validation (Ethiopian calendar & clock conversion, sanity checks)
  → schedules.json + poster images on GitHub Pages
```

It doesn't need a server, a database or a Telegram account. Everything runs on free tiers:
GitHub Actions, GitHub Pages and the Gemini API.

- The model only transcribes what's printed. Ethiopian dates and Ethiopian clock times
  (e.g. "3 ሰዓት" = 09:00) are converted in code.
- Anything doubtful is dropped rather than published, for example an ambiguous am/pm, a date that
  doesn't match its weekday, or a date outside the next two weeks.
- Each showtime links to the original poster and Telegram post. If a poster can't be read,
  the latest poster is still shown, so a cinema never has nothing to show.
- If a channel disappears or extraction keeps failing, the run fails and GitHub sends an email.

## Using the data

```js
const data = await fetch("https://etdvlpr.github.io/cinema/schedules.json").then(r => r.json());

for (const cinema of data.cinemas) {
  console.log(cinema.name, cinema.showtimes.length, "upcoming showtimes");
  // poster paths are relative to schedules.json
  const posterUrl = cinema.latest_poster && new URL(cinema.latest_poster.image, "https://etdvlpr.github.io/cinema/");
}
```

Each showtime has `date` (Gregorian, `YYYY-MM-DD`), `time` (24h, Addis Ababa local time),
`film_title` (as printed, often in Amharic), `film_title_latin`, `hall`, `format`, `language`,
`price_birr`, `confidence`, `poster` and `post_url`. Only today's and future showtimes are
included. The full format is in the [backend README](backend/README.md#output-publicschedulesjson).

Posters belong to the cinemas; this project links back to the original post for each one.

Film details and posters for international releases come from [TMDB](https://www.themoviedb.org).
This product uses the TMDB API but is not endorsed or certified by TMDB.

## App

[`app/`](app) is a Flutter app (Android, iOS and web) that reads this data. It has a "What's on"
view by film, a view by cinema, and, for every showtime, the original poster and Telegram post one
tap away. See [`app/README.md`](app/README.md).

## Development

See [`backend/README.md`](backend/README.md) for setup, running locally, the validation rules and
maintenance notes.

```bash
cd backend
python3 -m venv .venv && .venv/bin/pip install -e '.[dev]'
.venv/bin/pytest
.venv/bin/python -m cinema_pipeline run --dry-run   # scrape only, no model calls
```
