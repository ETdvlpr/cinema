/// Mirrors backend/public/schedules.json.
library;

import 'api.dart';

class Schedule {
  Schedule({required this.generatedAt, required this.cinemas, required this.films});

  final DateTime generatedAt;
  final List<Cinema> cinemas;

  /// Details per film key (TMDB data and/or a thumbnail cut from the cinema's poster).
  final Map<String, FilmInfo> films;

  factory Schedule.fromJson(Map<String, dynamic> json) {
    final imageBase = json['tmdb_image_base'] as String? ?? 'https://image.tmdb.org/t/p/';
    final films = {
      for (final e in (json['films'] as Map<String, dynamic>? ?? const {}).entries)
        e.key: FilmInfo.fromJson(e.value as Map<String, dynamic>, imageBase),
    };
    final schedule = Schedule(
      generatedAt: DateTime.parse(json['generated_at'] as String),
      cinemas: [for (final c in json['cinemas'] as List) Cinema.fromJson(c as Map<String, dynamic>)],
      films: films,
    );
    for (final s in schedule.allShowtimes) {
      s.info = films[s.filmKey];
    }
    return schedule;
  }

  Iterable<Showtime> get allShowtimes => cinemas.expand((c) => c.showtimes);
}

class Cinema {
  Cinema({
    required this.id,
    required this.name,
    required this.channelUrl,
    required this.mapsUrl,
    required this.lastChecked,
    required this.lastError,
    required this.latestSchedulePostedAt,
    required this.latestPoster,
    required this.showtimes,
  });

  final String id;
  final String name;
  final String channelUrl;
  final String? mapsUrl; // directions to the venue
  final DateTime? lastChecked;
  final String? lastError;
  final DateTime? latestSchedulePostedAt;
  final Poster? latestPoster;
  final List<Showtime> showtimes;

  factory Cinema.fromJson(Map<String, dynamic> json) {
    final cinema = Cinema(
      id: json['id'] as String,
      name: json['name'] as String,
      channelUrl: json['channel_url'] as String,
      mapsUrl: json['maps_url'] as String?,
      lastChecked: _date(json['last_checked']),
      lastError: json['last_error'] as String?,
      latestSchedulePostedAt: _date(json['latest_schedule_posted_at']),
      latestPoster: json['latest_poster'] == null
          ? null
          : Poster.fromJson(json['latest_poster'] as Map<String, dynamic>),
      showtimes: [],
    );
    cinema.showtimes.addAll([
      for (final s in json['showtimes'] as List) Showtime.fromJson(s as Map<String, dynamic>, cinema),
    ]);
    return cinema;
  }

  /// No new schedule for a while: the app shows a gentle warning and the source poster.
  bool get isStale {
    final posted = latestSchedulePostedAt;
    return posted == null || DateTime.now().difference(posted) > const Duration(days: 5);
  }
}

class Poster {
  Poster({required this.image, required this.postUrl, required this.postedAt});

  final String? image;
  final String postUrl;
  final DateTime postedAt;

  factory Poster.fromJson(Map<String, dynamic> json) => Poster(
    image: json['image'] as String?,
    postUrl: json['post_url'] as String,
    postedAt: DateTime.parse(json['posted_at'] as String),
  );
}

class Showtime {
  Showtime({
    required this.cinema,
    required this.date,
    required this.time,
    required this.filmTitle,
    required this.filmTitleLatin,
    required this.hall,
    required this.format,
    required this.language,
    required this.priceBirr,
    required this.confidence,
    required this.poster,
    required this.postUrl,
  });

  final Cinema cinema;

  /// Addis Ababa local date, YYYY-MM-DD.
  final String date;

  /// Addis Ababa local time, HH:MM (24h).
  final String time;
  final String filmTitle;
  final String filmTitleLatin;
  final String? hall;
  final String? format;
  final String? language;
  final double? priceBirr;
  final double confidence;
  final String? poster;
  final String postUrl;

  /// Set by [Schedule.fromJson].
  FilmInfo? info;

  factory Showtime.fromJson(Map<String, dynamic> json, Cinema cinema) => Showtime(
    cinema: cinema,
    date: json['date'] as String,
    time: json['time'] as String,
    filmTitle: json['film_title'] as String,
    filmTitleLatin: json['film_title_latin'] as String,
    hall: json['hall'] as String?,
    format: json['format'] as String?,
    language: json['language'] as String?,
    priceBirr: (json['price_birr'] as num?)?.toDouble(),
    confidence: (json['confidence'] as num).toDouble(),
    poster: json['poster'] as String?,
    postUrl: json['post_url'] as String,
  );

  /// Same film across cinemas, despite "SPIDER-MAN: Brand New Day" vs "SPIDER MAN: BRAND NEW DAY".
  String get filmKey => filmTitleLatin.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

  /// Sortable "YYYY-MM-DD HH:MM" in Addis local time.
  String get sortKey => '$date $time';
}

class FilmInfo {
  FilmInfo({
    required this.title,
    required this.overview,
    required this.releaseDate,
    required this.runtime,
    required this.genres,
    required this.rating,
    required this.certification,
    required this.tmdbUrl,
    required this.trailerUrl,
    required this.posterPath,
    required this.backdropPath,
    required this.thumbnail,
    required this.imageBase,
  });

  final String title;
  final String? overview;
  final String? releaseDate;
  final int? runtime;
  final List<String> genres;
  final double? rating;
  final String? certification;
  final String? tmdbUrl;
  final String? trailerUrl;
  final String? posterPath;
  final String? backdropPath;

  /// Artwork cut from the cinema's own schedule poster (relative to schedules.json).
  final String? thumbnail;
  final String imageBase;

  factory FilmInfo.fromJson(Map<String, dynamic> json, String imageBase) => FilmInfo(
    title: json['title'] as String,
    overview: json['overview'] as String?,
    releaseDate: json['release_date'] as String?,
    runtime: json['runtime'] as int?,
    genres: [for (final g in json['genres'] as List? ?? const []) g as String],
    rating: (json['rating'] as num?)?.toDouble(),
    certification: json['certification'] as String?,
    tmdbUrl: json['tmdb_url'] as String?,
    trailerUrl: json['trailer_url'] as String?,
    posterPath: json['poster_path'] as String?,
    backdropPath: json['backdrop_path'] as String?,
    thumbnail: json['thumbnail'] as String?,
    imageBase: imageBase,
  );

  bool get fromTmdb => tmdbUrl != null;

  String? get year => releaseDate != null && releaseDate!.length >= 4 ? releaseDate!.substring(0, 4) : null;

  /// TMDB poster at [size] (w92, w154, w185, w342, w500, w780), else the thumbnail cut from
  /// the cinema's poster, else null.
  String? poster(String size) {
    if (posterPath != null) return '$imageBase$size$posterPath';
    if (thumbnail != null) return assetUrl(thumbnail!);
    return null;
  }

  /// Wide image for headers: TMDB backdrop at [size] (w300, w780, w1280), else null.
  String? backdrop(String size) => backdropPath == null ? null : '$imageBase$size$backdropPath';
}

DateTime? _date(Object? value) => value == null ? null : DateTime.parse(value as String);
