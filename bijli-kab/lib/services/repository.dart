import '../models/models.dart';

/// Where reports come from and go to.
///
/// [FirebaseRepository] is the real, shared backend. [DemoRepository] is a
/// self-contained simulation used until Firebase is configured, so the app
/// is fully usable (and reviewable) out of the box.
abstract class PowerRepository {
  bool get isLive;
  String get uid;

  Future<void> init();

  /// Reports for [areaId] from the last [window], updating live.
  Stream<List<PowerReport>> watchReports(String areaId, Duration window);

  Future<void> submitReport({
    required SavedArea area,
    required bool on,
    required PowerIssue issue,
    required bool changesState,
    required int points,
  });

  /// Areas whose geohash starts with [prefix] (for the map).
  Future<List<AreaSnapshot>> nearby(String prefix);

  Future<List<LeaderEntry>> leaderboard({String? city});

  Future<void> saveProfile({
    required String name,
    required String avatar,
    required String city,
  });
}
