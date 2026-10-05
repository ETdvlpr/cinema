# Cinema schedules: backend

```
t.me/s/<channel>  →  GitHub Action (every 6h)  →  Gemini vision  →  validation  →  public/schedules.json + posters  →  GitHub Pages
```

No server, no database, no Telegram account. A scheduled GitHub Action reads each cinema's public
Telegram web preview, sends new poster images to a vision model, validates what comes back,
commits the results, and publishes `public/` to GitHub Pages. If anything breaks, the run fails
and GitHub emails you.

## Setup

1. Push this repo to GitHub. The workflow lives at `.github/workflows/update-schedules.yml` in the
   repo root and expects this folder at `backend/`. Use a public repo, which gets Actions minutes free.
2. Get a Gemini API key at https://aistudio.google.com/apikey and add it as the repository secret
   `GEMINI_API_KEY` (Settings → Secrets and variables → Actions).
3. Settings → Pages → Source: **GitHub Actions**.
4. Edit `cinemas.yaml` with the real channel names. Check that each `https://t.me/s/<channel>` loads in a browser.
5. Actions → *Update schedules* → **Run workflow** to run it once immediately.

The app then reads `https://<user>.github.io/<repo>/schedules.json`. GitHub Pages sends
`Access-Control-Allow-Origin: *`, so a PWA hosted elsewhere can fetch it.

Optional: set the repository variable `GEMINI_MODEL` to a comma-separated list of models. They're
tried in order, and each has its own free-tier quota. The default is
`gemini-flash-latest,gemini-flash-lite-latest`, which keeps working when Google retires older models.

## Local development

```bash
cd backend
python3 -m venv .venv && .venv/bin/pip install -e '.[dev]'
.venv/bin/pytest

# Scrape only, with no model calls and no files written:
.venv/bin/python -m cinema_pipeline run --dry-run

# Tune extraction on a single poster:
GEMINI_API_KEY=... .venv/bin/python -m cinema_pipeline extract poster.jpg --posted-on 2026-10-05

# Full run (writes data/ and public/):
GEMINI_API_KEY=... .venv/bin/python -m cinema_pipeline run [--cinema edna-mall]
```

## How extraction stays trustworthy

The model only **transcribes**. For each screening it returns the printed numbers and says which
system they use: Ethiopian or Gregorian calendar, and Ethiopian or western clock with
day/night or am/pm. All conversion happens in `ethiopian.py`, never in the model.

`validate.py` then drops anything doubtful:

| Check | Example |
|---|---|
| confidence ≥ 0.6 | |
| date between post date −1 and +14 days | stops calendar mix-ups from publishing a date months away |
| printed weekday matches the converted date | catches off-by-one calendar errors |
| time within 09:00–23:00 | |
| ambiguity → reject | "10:30" with no am/pm could be 10:30 or 22:30, so it's dropped. "8:00" resolves to 20:00 because 08:00 is outside screening hours. |
| duplicate slots removed | |

When the calendar is unknown (for example "10/8"), every reading is tried. The value is kept
only if exactly one reading passes. You can tune all thresholds at the top of `config.py`.

Rejected entries are stored with a reason in `data/extractions/<cinema>.json`, so you can see what
the model got wrong.

**Newer posts win.** If a cinema posts a corrected schedule that covers a date, older posters'
showtimes for that date are discarded.

**There's always something to show.** Every cinema in `schedules.json` has a `latest_poster`
(the original image, plus a link to the Telegram post), even when extraction failed.

## Output: `public/schedules.json`

```jsonc
{
  "generated_at": "2026-10-05T21:17:00+03:00",
  "timezone": "Africa/Addis_Ababa",
  "cinemas": [
    {
      "id": "edna-mall",
      "name": "Edna Mall Cinema",
      "channel_url": "https://t.me/...",
      "last_checked": "2026-10-05T21:17:00+03:00",   // when the channel was last read
      "last_error": null,                            // set if the channel couldn't be read
      "latest_schedule_posted_at": "2026-10-04T...", // newest poster that yielded showtimes; use for "stale" warnings
      "latest_poster": { "image": "posters/edna-mall/123-0.jpg", "post_url": "...", "posted_at": "...", "status": "ok" },
      "showtimes": [
        {
          "date": "2026-10-06", "time": "20:30",          // Gregorian date, 24h, Addis local time
          "film_title": "...", "film_title_latin": "...",
          "hall": null, "format": "2D", "language": null, "price_birr": 350,
          "confidence": 0.9,
          "poster": "posters/edna-mall/123-0.jpg",         // relative to schedules.json
          "post_url": "https://t.me/.../123"
        }
      ]
    }
  ]
}
```

Only showtimes from today onward are included.

## Layout

```
cinemas.yaml                 channels to watch
src/cinema_pipeline/
  scrape.py                  t.me/s/<channel> → images (public preview, no login)
  extract.py                 vision model call + response schema (swap providers in _call_model)
  ethiopian.py               calendar and clock conversion
  validate.py                raw model output → accepted showtimes / rejections
  store.py                   per-cinema memory in data/extractions/
  publish.py                 builds public/schedules.json
  pipeline.py                orchestration
data/extractions/            committed state: every poster seen, its status and results
public/                      published to GitHub Pages
```

## Maintenance notes

- **Failure emails.** A run fails, and GitHub emails you, when a channel can't be read (renamed,
  went private, or Telegram changed the page), when an image fails 3 times, or when a poster still
  hasn't been extracted 24h after the first try. Temporary quota or overload errors don't trigger
  an email on their own. The run fails only *after* publishing, so other cinemas still update.
  The run summary lists the problems.
- **Free-tier quota.** Free Gemini tiers can be as low as 20 requests per model per day, so the
  pipeline is careful with them:
  - It only sends posters from the last 7 days to the model.
  - It processes the newest posters first, across all cinemas.
  - When a model is over quota (429) or overloaded (503), it falls back to the next model.
  - It stops calling the model for the rest of the run once every model is over quota.
  - Quota and overload errors don't count toward an image's 3 attempts.

  Five cinemas post roughly 5–10 new images a day, which fits within the free tiers.
- **Pruning.** Posters and records older than 30 days are deleted. Images that aren't schedules
  are deleted right away. Posters are resized to ≤1280px JPEG, about 75–150 KB each.
- **Repo size.** Posters are committed, so git history grows slowly, roughly a few MB per month
  for a few dozen cinemas. If that ever matters, squash history or move posters to another store.
- **Inactive repos.** GitHub disables scheduled workflows in repos with no activity for 60 days.
  This workflow's own commits normally count as activity. If GitHub disables it anyway, you'll
  get an email and can re-enable it with one click.
- **Model retirement.** If Google renames or retires the model, set the `GEMINI_MODEL` variable.
  To switch providers, rewrite `_call_model` in `extract.py`.
