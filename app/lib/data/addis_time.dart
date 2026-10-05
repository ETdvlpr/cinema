/// Showtimes are in Addis Ababa local time (UTC+3, no DST), whatever the phone's timezone is.
library;

DateTime addisNow() => DateTime.now().toUtc().add(const Duration(hours: 3));

String isoDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

String addisToday() => isoDate(addisNow());

String addisNowHm() {
  final now = addisNow();
  return '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
}

/// "2026-10-05" -> DateTime(2026, 10, 5) (date only, no timezone semantics).
DateTime parseIsoDate(String date) {
  final parts = date.split('-').map(int.parse).toList();
  return DateTime(parts[0], parts[1], parts[2]);
}

const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _weekdaysLong = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

String weekdayShort(String date) => _weekdays[parseIsoDate(date).weekday - 1];

String monthShort(String date) => _months[parseIsoDate(date).month - 1];

int dayOfMonth(String date) => parseIsoDate(date).day;

/// "Today", "Tomorrow", or "Wednesday 7 Oct".
String friendlyDate(String date) {
  final today = parseIsoDate(addisToday());
  final d = parseIsoDate(date);
  final diff = d.difference(today).inDays;
  if (diff == 0) return 'Today';
  if (diff == 1) return 'Tomorrow';
  return '${_weekdaysLong[d.weekday - 1]} ${d.day} ${_months[d.month - 1]}';
}

/// "18:20" -> "6:20 PM"
String to12h(String hm) {
  final parts = hm.split(':');
  final h = int.parse(parts[0]);
  final suffix = h >= 12 ? 'PM' : 'AM';
  final h12 = h % 12 == 0 ? 12 : h % 12;
  return '$h12:${parts[1]} $suffix';
}

/// The same time on the Ethiopian clock, e.g. "18:20" -> "12:20 ማታ". Hours count from 6 AM/PM.
String toEthiopianClock(String hm) {
  final parts = hm.split(':');
  final h = int.parse(parts[0]);
  final eh = (h + 6) % 12 == 0 ? 12 : (h + 6) % 12;
  final period = switch (h) {
    >= 6 && < 12 => 'ጠዋት',
    >= 12 && < 18 => 'ከሰዓት',
    >= 18 => 'ማታ',
    _ => 'ሌሊት',
  };
  return '$eh:${parts[1]} $period';
}

/// "3 hours ago", "just now"
String timeAgo(DateTime then) {
  final d = DateTime.now().difference(then);
  if (d.inMinutes < 2) return 'just now';
  if (d.inMinutes < 60) return '${d.inMinutes} min ago';
  if (d.inHours < 24) return '${d.inHours} h ago';
  return '${d.inDays} d ago';
}
