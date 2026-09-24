import 'package:intl/intl.dart';

final _hm = DateFormat('HH:mm');
final _day = DateFormat('EEE d MMM');

/// 24-hour clock, like a timetable.
String hm(DateTime t) => _hm.format(t.toLocal());

String dayLabel(DateTime d) => _day.format(d.toLocal());

DateTime? parseTime(Object? v) => v == null ? null : DateTime.parse(v as String);

/// "+12 min", "On time", "2 min early"
String delayLabel(int minutes) {
  if (minutes >= 1) return '+$minutes min';
  if (minutes <= -2) return '${-minutes} min early';
  return 'On time';
}

/// "in 6 min", "now", "4 min ago"
String relative(DateTime t, {DateTime? now}) {
  final diff = t.difference(now ?? DateTime.now()).inMinutes;
  if (diff.abs() < 1) return 'now';
  if (diff > 0) return diff < 60 ? 'in $diff min' : 'at ${hm(t)}';
  return -diff < 60 ? '${-diff} min ago' : hm(t);
}
