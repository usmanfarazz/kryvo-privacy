import 'strings.dart';

/// "2h 15m", "45m", "3d 4h" — words in the current language.
String fmtDuration(Duration d) {
  final m = d.inMinutes;
  if (m < 1) return tr('just now');
  if (m < 60) return trf('{0}m', [m]);
  final h = m ~/ 60, r = m % 60;
  if (h == 1) return r == 0 ? tr('1h') : trf('1h {1}m', [h, r]);
  if (h < 24) return r == 0 ? trf('{0}h', [h]) : trf('{0}h {1}m', [h, r]);
  final days = h ~/ 24, hh = h % 24;
  return hh == 0 ? trf('{0}d', [days]) : trf('{0}d {1}h', [days, hh]);
}

/// Compact "2h 11m" for big numbers in stat tiles.
String fmtDurationShort(Duration d) {
  final m = d.inMinutes;
  if (m < 60) return '${m}m';
  final h = m ~/ 60, r = m % 60;
  if (h < 24) return r == 0 ? '${h}h' : '${h}h ${r}m';
  return '${h ~/ 24}d ${h % 24}h';
}

/// Hours as "12.5h" for stats.
String fmtHours(double h) => h >= 10 || h == h.roundToDouble()
    ? '${h.round()}h'
    : '${h.toStringAsFixed(1)}h';

/// "3:45 PM".
String fmtTime(DateTime t) {
  final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
  final m = t.minute.toString().padLeft(2, '0');
  return '$h:$m ${t.hour < 12 ? tr('AM') : tr('PM')}';
}

/// "5 min ago", "2h ago".
String fmtAgo(DateTime t, [DateTime? now]) {
  final d = (now ?? DateTime.now()).difference(t);
  if (d.inMinutes < 1) return tr('just now');
  return trf('{0} ago', [fmtDuration(d)]);
}

/// "in 25m", "in 2h 10m".
String fmtIn(DateTime t, [DateTime? now]) {
  final d = t.difference(now ?? DateTime.now());
  if (d.inMinutes < 1) return tr('any moment');
  return trf('in {0}', [fmtDuration(d)]);
}

const _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
String dayShort(int weekday) => tr(_days[weekday - 1]);

/// "Today", "Tomorrow", "Mon".
String fmtDay(DateTime t, [DateTime? now]) {
  final n = now ?? DateTime.now();
  final a = DateTime(n.year, n.month, n.day);
  final b = DateTime(t.year, t.month, t.day);
  final diff = b.difference(a).inDays;
  if (diff == 0) return tr('Today');
  if (diff == 1) return tr('Tomorrow');
  if (diff == -1) return tr('Yesterday');
  return dayShort(t.weekday);
}

String hourLabel(int h) {
  final hh = h % 12 == 0 ? 12 : h % 12;
  return '$hh${h < 12 ? 'a' : 'p'}';
}
