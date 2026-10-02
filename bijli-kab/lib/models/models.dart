/// Plain data classes shared by the services and screens.
library;

/// A place the user follows (home, office, parents' house …).
class SavedArea {
  final String id; // geohash cell
  final String label; // user's name for it: "Ghar", "Office"
  final String emoji;
  final String place; // reverse-geocoded locality: "Gulberg III"
  final String city;
  final double lat, lng;

  const SavedArea({
    required this.id,
    required this.label,
    required this.emoji,
    required this.place,
    required this.city,
    required this.lat,
    required this.lng,
  });

  String get title => label.isNotEmpty ? label : place;
  String get subtitle =>
      [place, city].where((s) => s.isNotEmpty).toSet().join(', ');

  SavedArea copyWith({String? label, String? emoji}) => SavedArea(
    id: id,
    label: label ?? this.label,
    emoji: emoji ?? this.emoji,
    place: place,
    city: city,
    lat: lat,
    lng: lng,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'label': label,
    'emoji': emoji,
    'place': place,
    'city': city,
    'lat': lat,
    'lng': lng,
  };

  factory SavedArea.fromJson(Map<String, dynamic> j) => SavedArea(
    id: j['id'] as String,
    label: (j['label'] ?? '') as String,
    emoji: (j['emoji'] ?? '🏠') as String,
    place: (j['place'] ?? '') as String,
    city: (j['city'] ?? '') as String,
    lat: (j['lat'] as num).toDouble(),
    lng: (j['lng'] as num).toDouble(),
  );
}

/// Area mood reactions.
const kAlertSounds = ['chime', 'bell', 'siren', 'horn'];

const kMoods = ['😩', '🥵', '🕯️', '😡', '🎉'];

/// Optional detail a reporter can attach.
enum PowerIssue {
  none,
  lowVoltage,
  tripping,
  transformer,
  scheduled,
  wireFault,
}

PowerIssue issueFromName(String? s) => PowerIssue.values.firstWhere(
  (e) => e.name == s,
  orElse: () => PowerIssue.none,
);

/// One "light gayi / light aayi" tap.
class PowerReport {
  final String uid;
  final bool on;
  final DateTime at;
  final PowerIssue issue;
  const PowerReport({
    required this.uid,
    required this.on,
    required this.at,
    this.issue = PowerIssue.none,
  });
}

enum PowerState { on, off, unknown }

/// A stretch of time with one state.
class Segment {
  final PowerState state;
  final DateTime start;
  final DateTime end;
  final int reporters; // distinct people who confirmed this state
  const Segment(this.state, this.start, this.end, this.reporters);
  Duration get duration => end.difference(start);
}

/// The current picture for one area.
class AreaStatus {
  final PowerState state;
  final DateTime? since;
  final double confidence; // 0..1
  final int reporters; // distinct people agreeing recently
  final DateTime? lastReport;
  final PowerIssue issue;
  const AreaStatus({
    required this.state,
    this.since,
    this.confidence = 0,
    this.reporters = 0,
    this.lastReport,
    this.issue = PowerIssue.none,
  });
  static const unknown = AreaStatus(state: PowerState.unknown);
}

/// A predicted outage window.
class PredictedOutage {
  final DateTime start;
  final DateTime end;
  final double probability; // 0..1
  final bool fromSchedule;
  const PredictedOutage(
    this.start,
    this.end,
    this.probability, {
    this.fromSchedule = false,
  });
  Duration get duration => end.difference(start);
}

/// A slot from the official schedule the user typed in.
class ScheduleSlot {
  final int weekdayMask; // bit 0 = Monday … bit 6 = Sunday; 127 = every day
  final int startMinute; // minutes after midnight
  final int durationMinutes;
  const ScheduleSlot(this.weekdayMask, this.startMinute, this.durationMinutes);

  bool appliesOn(int weekday) => weekdayMask & (1 << (weekday - 1)) != 0;

  Map<String, dynamic> toJson() => {
    'w': weekdayMask,
    's': startMinute,
    'd': durationMinutes,
  };
  factory ScheduleSlot.fromJson(Map<String, dynamic> j) =>
      ScheduleSlot(j['w'] as int, j['s'] as int, j['d'] as int);
}

/// A cell shown on the live map.
class AreaSnapshot {
  final String id;
  final String place;
  final String city;
  final double lat, lng;
  final PowerState state;
  final DateTime? since;
  final DateTime? updated;
  final int reports24h;
  const AreaSnapshot({
    required this.id,
    required this.place,
    required this.city,
    required this.lat,
    required this.lng,
    required this.state,
    this.since,
    this.updated,
    this.reports24h = 0,
  });

  /// Older than 3 hours without a report → we honestly don't know.
  PowerState get freshState =>
      updated == null || DateTime.now().difference(updated!).inHours >= 3
      ? PowerState.unknown
      : state;
}

class LeaderEntry {
  final String uid;
  final String name;
  final String avatar;
  final String city;
  final int points;
  final int reports;
  const LeaderEntry({
    required this.uid,
    required this.name,
    required this.avatar,
    required this.city,
    required this.points,
    required this.reports,
  });
}
