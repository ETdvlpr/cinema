# Addis Cinema: Flutter app

A mobile and web app for the showtimes the [backend](../backend) publishes at
`https://etdvlpr.github.io/cinema/schedules.json`.

## Features

- **Movies tab ("What's on"):** a date strip, a carousel of the films showing that day, and every
  screening grouped by film and then by cinema.
- **Cinemas tab:** each cinema's films for the day. If none could be read, it offers the
  cinema's latest poster instead.
- **Film page:** every upcoming screening of a film across all cinemas, by day. When TMDB knows
  the film, the page also shows the backdrop, rating, year, runtime, certification, genres, the
  summary and a trailer link, with TMDB credited as its terms require.
- **Real artwork:** the TMDB poster when there is one, otherwise the artwork cropped from the
  cinema's own schedule poster (this covers Amharic films too), otherwise generated art. Image
  sizes are matched to where they're shown (a 154px list thumbnail, a 342px carousel card), so
  they stay light on data.
- **Cinema page:** the cinema's logo, its schedule by day, its latest poster, Google Maps
  directions and a Telegram link. It warns if the schedule is stale or the channel couldn't be read.
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
`web/index.html` shows a loading screen until Flutter draws its first frame.

The website is live at **https://etcinema.vercel.app** (Vercel project `etcinema`). To redeploy
after `flutter build web --release`:

```bash
cd build/web
vercel link --project etcinema --yes   # once per fresh build folder
vercel deploy --prod --yes
```

Only deploy a clean build: Vercel publishes everything in `build/web` as public files.

## Releasing the Android app

Release builds are signed with the upload key in `android/key.properties` (not committed; without
it they fall back to the debug key). Keep the keystore backed up: Android only installs updates
signed with the same key.

1. Bump `version:` in `pubspec.yaml` (the `+N` build number must go up every release).
2. Build both the ARM APK that every phone can install, and the smaller per-architecture ones:

   ```bash
   flutter build apk --release --target-platform android-arm,android-arm64
   cp build/app/outputs/flutter-apk/app-release.apk addis-cinema.apk
   flutter build apk --release --split-per-abi --target-platform android-arm,android-arm64
   cp build/app/outputs/flutter-apk/app-arm64-v8a-release.apk addis-cinema-arm64.apk
   cp build/app/outputs/flutter-apk/app-armeabi-v7a-release.apk addis-cinema-armv7.apk
   ```

3. Publish them as a GitHub release (tag `vX.Y.Z`). Keep the file name `addis-cinema.apk`: the
   website's "Get the Android app" banner, shown to Android browsers, links to
   `releases/latest/download/addis-cinema.apk`.

   ```bash
   gh release create vX.Y.Z addis-cinema.apk addis-cinema-arm64.apk addis-cinema-armv7.apk
   ```

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
assets/cinemas/<id>.jpg        cinema logos, from each cinema's own Telegram/social profile
```
