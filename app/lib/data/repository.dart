import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'api.dart';
import 'models.dart';

export 'api.dart' show apiBase, assetUrl;

class ScheduleResult {
  ScheduleResult(this.schedule, {required this.fromCache});

  final Schedule schedule;

  /// True when the network failed and we're showing the last saved copy.
  final bool fromCache;
}

/// Fetches schedules.json, keeping the last good copy so the app works offline.
class ScheduleRepository {
  static const _cacheKey = 'schedules_json';

  Future<Schedule?> cached() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_cacheKey);
      return raw == null ? null : Schedule.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<ScheduleResult> fetch() async {
    try {
      final response = await http.get(Uri.parse(assetUrl('schedules.json'))).timeout(const Duration(seconds: 20));
      if (response.statusCode != 200) throw http.ClientException('HTTP ${response.statusCode}');
      final body = utf8.decode(response.bodyBytes);
      final schedule = Schedule.fromJson(jsonDecode(body) as Map<String, dynamic>);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cacheKey, body);
      return ScheduleResult(schedule, fromCache: false);
    } catch (_) {
      final saved = await cached();
      if (saved != null) return ScheduleResult(saved, fromCache: true);
      rethrow;
    }
  }
}
