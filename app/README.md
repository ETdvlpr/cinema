# Addis Cinema: Flutter app

A mobile and web app for the showtimes the [backend](../backend) publishes at
`https://etdvlpr.github.io/cinema/schedules.json`.

## Features

- **Movies tab ("What's on"):** a date strip, a carousel of the films showing that day, and every
  screening grouped by film and then by cinema.
- **Cinemas tab:** each cinema's films for the day. If none could be read, it offers the
  cinema's latest poster instead.
- **Film page:** every upcoming screening of a film across all cinemas, by day.
- **Cinema page:** the cinema's schedule by day, its latest poster and a Telegram link. It warns if
  the schedule is stale or the channel couldn't be read.
- **Showtime sheet:** tap any time to see the date, the time on both the western and Ethiopian
  clocks (e.g. 6:20 PM / 12:20 ማታ), hall, format and price, plus the cinema's **original poster**
  and the Telegram post, so people can check it themselves.
- **Data use and offline:**
  - The schedule is one small JSON file, cached for offline use.
  - Posters download only when someone taps one, then they're cached.
  - Film artwork is generated from the title, so it costs no data.
- **Showtimes are in Addis Ababa time,** whatever timezone the phone is set to. Showtimes that have
  already started are hidden, and ones starting within the hour are highlighted.
- **Spelling variants merged:** the same film is grouped across cinemas even when its spelling
  differs (e.g. "SPIDER-MAN: BRAND NEW DAY" and "SPIDER MAN: BRAND NEW DAY").

## Run

```bash
flutter pub get
flutter run                 # Android / iOS device or simulator
flutter run -d chrome       # web
flutter test
```

To point at a different backend, for example a local one:

```bash
flutter run --dart-define=API_BASE=http://localhost:8000/
```

## Build

```bash
flutter build apk --release        # Android
flutter build ipa                  # iOS (needs signing)
flutter build web --release        # static files in build/web, installable as a PWA
```

The web build can be hosted anywhere static, including GitHub Pages or Vercel. The backend serves
`schedules.json` with `Access-Control-Allow-Origin: *`, so the app can fetch it from another domain.

## Code

```
lib/
  main.dart                    app, theme, refresh when the app comes back to the foreground
  data/models.dart             schedules.json types
  data/repository.dart         fetch + offline cache (API_BASE)
  data/films.dart              grouping showtimes into films, title clean-up
  data/addis_time.dart         Addis Ababa time, Ethiopian clock display
  state/schedule_controller.dart
  ui/home_page.dart            tabs: Movies, Cinemas
  ui/movie_page.dart
  ui/cinema_page.dart
  ui/poster_page.dart          zoomable original poster
  ui/widgets/                  film art, day selector, time chips, showtime sheet, banners
```

The app icons are still Flutter's defaults. Replace them before publishing, for example with
[`flutter_launcher_icons`](https://pub.dev/packages/flutter_launcher_icons).
