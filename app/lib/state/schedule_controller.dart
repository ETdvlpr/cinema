import 'package:flutter/foundation.dart';

import '../data/addis_time.dart';
import '../data/films.dart';
import '../data/models.dart';
import '../data/repository.dart';

class ScheduleController extends ChangeNotifier {
  ScheduleController(this._repository);

  final ScheduleRepository _repository;

  Schedule? schedule;
  bool loading = false;
  bool offline = false;
  Object? error;
  String? _selectedDate;

  Future<void> load() async {
    schedule ??= await _repository.cached();
    if (schedule != null) notifyListeners();
    await refresh();
  }

  Future<void> refresh() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      final result = await _repository.fetch();
      schedule = result.schedule;
      offline = result.fromCache;
    } catch (e) {
      error = e;
      offline = true;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  /// Upcoming showtimes only: on today's date, ones that already started are dropped.
  List<Showtime> get upcoming {
    final today = addisToday();
    final now = addisNowHm();
    return [
      for (final s in schedule?.allShowtimes ?? const <Showtime>[])
        if (s.date.compareTo(today) > 0 || (s.date == today && s.time.compareTo(now) >= 0)) s,
    ];
  }

  /// Dates that have at least one upcoming showtime, in order.
  List<String> get dates => ({for (final s in upcoming) s.date}.toList()..sort());

  String? get selectedDate {
    final available = dates;
    if (available.isEmpty) return null;
    return available.contains(_selectedDate) ? _selectedDate : available.first;
  }

  void selectDate(String date) {
    _selectedDate = date;
    notifyListeners();
  }

  List<Showtime> showtimesOn(String date) => [
    for (final s in upcoming)
      if (s.date == date) s,
  ];

  List<Film> filmsOn(String date) => groupFilms(showtimesOn(date));

  List<Film> get allFilms => groupFilms(upcoming);

  Film? film(String key) {
    for (final f in allFilms) {
      if (f.key == key) return f;
    }
    return null;
  }

  Cinema? cinema(String id) {
    for (final c in schedule?.cinemas ?? const <Cinema>[]) {
      if (c.id == id) return c;
    }
    return null;
  }
}
