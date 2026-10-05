import 'models.dart';

/// A film and all its showtimes, grouped across cinemas.
class Film {
  Film(this.key, this.showtimes);

  final String key;
  final List<Showtime> showtimes;

  FilmInfo? get info => showtimes.first.info;

  /// TMDB's title when known, else the most common spelling, made pleasant to read
  /// ("RESIDENT EVIL" -> "Resident Evil").
  String get title {
    final known = info;
    if (known != null && known.fromTmdb) return known.title;
    // Vote case-insensitively, so "BRAND NEW DAY" and "BRAND New DAY" count as one spelling.
    final counts = <String, int>{};
    final spelling = <String, String>{};
    for (final s in showtimes) {
      final lower = s.filmTitleLatin.toLowerCase();
      counts[lower] = (counts[lower] ?? 0) + 1;
      spelling.putIfAbsent(lower, () => s.filmTitleLatin);
    }
    final best = counts.entries.reduce((a, b) => b.value > a.value ? b : a).key;
    return prettyTitle(spelling[best]!);
  }

  /// The title as printed, when it's in another script (e.g. Amharic).
  String? get originalTitle {
    for (final s in showtimes) {
      if (s.filmTitle.isNotEmpty && RegExp(r'[^\x00-\x7F]').hasMatch(s.filmTitle)) return s.filmTitle;
    }
    return null;
  }

  Set<String> get cinemaIds => {for (final s in showtimes) s.cinema.id};

  Set<String> get formats => {
    for (final s in showtimes)
      if (s.format != null && s.format!.toUpperCase() != '2D') s.format!.toUpperCase(),
  };

  /// Showtimes for one cinema, sorted.
  Map<Cinema, List<Showtime>> byCinema() {
    final map = <Cinema, List<Showtime>>{};
    for (final s in showtimes) {
      map.putIfAbsent(s.cinema, () => []).add(s);
    }
    for (final list in map.values) {
      list.sort((a, b) => a.sortKey.compareTo(b.sortKey));
    }
    return map;
  }
}

List<Film> groupFilms(Iterable<Showtime> showtimes) {
  final map = <String, List<Showtime>>{};
  for (final s in showtimes) {
    map.putIfAbsent(s.filmKey, () => []).add(s);
  }
  final films = [for (final e in map.entries) Film(e.key, e.value)];
  // Most widely shown first, then by number of screenings.
  films.sort((a, b) {
    final c = b.cinemaIds.length.compareTo(a.cinemaIds.length);
    return c != 0 ? c : b.showtimes.length.compareTo(a.showtimes.length);
  });
  return films;
}

String prettyTitle(String title) {
  final letters = title.replaceAll(RegExp(r'[^A-Za-z]'), '');
  final mostlyUpper = letters.isNotEmpty && letters.replaceAll(RegExp(r'[^A-Z]'), '').length / letters.length > 0.7;
  if (!mostlyUpper) return title;
  const small = {'a', 'an', 'and', 'as', 'at', 'but', 'by', 'for', 'in', 'of', 'on', 'or', 'the', 'to', 'vs'};
  final words = title.toLowerCase().split(' ');
  return [
    for (var i = 0; i < words.length; i++)
      if (words[i].isEmpty)
        words[i]
      else if (i > 0 && small.contains(words[i]) && !words[i - 1].endsWith(':'))
        words[i]
      else
        _capitalize(words[i]),
  ].join(' ');
}

/// Capitalises each hyphen-separated part: "spider-man" -> "Spider-Man".
String _capitalize(String word) =>
    word.split('-').map((p) => p.isEmpty ? p : p[0].toUpperCase() + p.substring(1)).join('-');
