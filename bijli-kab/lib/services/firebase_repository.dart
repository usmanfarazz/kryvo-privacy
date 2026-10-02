import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/models.dart';
import 'geohash.dart';
import 'repository.dart';

/// The shared, live backend (Cloud Firestore + anonymous sign-in).
///
/// Layout (see firestore.rules):
///   areas/{geohash}                 latest state for the map
///   areas/{geohash}/reports/{auto}  every tap
///   users/{uid}                     nickname, avatar, points
class FirebaseRepository implements PowerRepository {
  final _db = FirebaseFirestore.instance;
  String _uid = '';

  @override
  bool get isLive => true;
  @override
  String get uid => _uid;

  @override
  Future<void> init() async {
    final auth = FirebaseAuth.instance;
    final user = auth.currentUser ?? (await auth.signInAnonymously()).user;
    _uid = user!.uid;
  }

  CollectionReference<Map<String, dynamic>> _reports(String areaId) =>
      _db.collection('areas').doc(areaId).collection('reports');

  @override
  Stream<List<PowerReport>> watchReports(String areaId, Duration window) {
    final from = DateTime.now().subtract(window);
    return _reports(areaId)
        .where('at', isGreaterThanOrEqualTo: Timestamp.fromDate(from))
        .orderBy('at')
        .snapshots()
        .map(
          (snap) => snap.docs.map((d) {
            final m = d.data();
            // Our own just-sent report has no server time yet (null).
            final at = m['at'];
            return PowerReport(
              uid: (m['uid'] ?? '') as String,
              on: m['on'] == true,
              at: at is Timestamp ? at.toDate() : DateTime.now(),
              issue: issueFromName(m['issue'] as String?),
            );
          }).toList(),
        );
  }

  @override
  Future<void> submitReport({
    required SavedArea area,
    required bool on,
    required PowerIssue issue,
    required bool changesState,
    required int points,
  }) async {
    final batch = _db.batch();
    final now = FieldValue.serverTimestamp();
    batch.set(_reports(area.id).doc(), {
      'uid': _uid,
      'on': on,
      'issue': issue == PowerIssue.none ? null : issue.name,
      'at': now,
      // Firestore TTL policy on `expire` deletes old reports (README).
      'expire': Timestamp.fromDate(
        DateTime.now().add(const Duration(days: 35)),
      ),
    });
    batch.set(_db.collection('areas').doc(area.id), {
      'place': area.place,
      'city': area.city,
      'lat': area.lat,
      'lng': area.lng,
      'p4': area.id.substring(0, kNearbyPrecision),
      'state': on ? 'on' : 'off',
      if (changesState) 'since': now,
      'updated': now,
      'n': FieldValue.increment(1),
    }, SetOptions(merge: true));
    batch.set(_db.collection('users').doc(_uid), {
      'points': FieldValue.increment(points),
      'reports': FieldValue.increment(1),
      'lastReport': now,
    }, SetOptions(merge: true));
    await batch.commit();
  }

  @override
  Stream<Map<String, int>> watchMoods(String areaId) {
    final from = DateTime.now().subtract(const Duration(hours: 3));
    return _db
        .collection('areas')
        .doc(areaId)
        .collection('moods')
        .where('at', isGreaterThanOrEqualTo: Timestamp.fromDate(from))
        .snapshots()
        .map((snap) {
          final m = {for (final e in kMoods) e: 0};
          for (final d in snap.docs) {
            final e = d.data()['e'];
            if (m.containsKey(e)) m[e as String] = m[e]! + 1;
          }
          return m;
        });
  }

  @override
  Future<void> setMood(String areaId, String emoji) =>
      _db.collection('areas').doc(areaId).collection('moods').doc(_uid).set({
        'e': emoji,
        'at': FieldValue.serverTimestamp(),
        'expire': Timestamp.fromDate(
          DateTime.now().add(const Duration(days: 2)),
        ),
      });

  @override
  Future<List<AreaSnapshot>> nearby(String prefix) async {
    final snap = await _db
        .collection('areas')
        .where('p4', isEqualTo: prefix.substring(0, kNearbyPrecision))
        .limit(300)
        .get();
    return snap.docs.map((d) {
      final m = d.data();
      DateTime? ts(String k) => (m[k] as Timestamp?)?.toDate();
      return AreaSnapshot(
        id: d.id,
        place: (m['place'] ?? '') as String,
        city: (m['city'] ?? '') as String,
        lat: (m['lat'] as num?)?.toDouble() ?? geohashDecode(d.id).lat,
        lng: (m['lng'] as num?)?.toDouble() ?? geohashDecode(d.id).lng,
        state: m['state'] == 'off' ? PowerState.off : PowerState.on,
        since: ts('since'),
        updated: ts('updated'),
        reports24h: (m['n'] as num?)?.toInt() ?? 0,
      );
    }).toList();
  }

  @override
  Future<List<LeaderEntry>> leaderboard({String? city}) async {
    Query<Map<String, dynamic>> q = _db.collection('users');
    if (city != null && city.isNotEmpty) q = q.where('city', isEqualTo: city);
    final snap = await q.orderBy('points', descending: true).limit(50).get();
    return snap.docs.map((d) {
      final m = d.data();
      return LeaderEntry(
        uid: d.id,
        name: (m['name'] ?? 'Reporter') as String,
        avatar: (m['avatar'] ?? '⚡') as String,
        city: (m['city'] ?? '') as String,
        points: (m['points'] as num?)?.toInt() ?? 0,
        reports: (m['reports'] as num?)?.toInt() ?? 0,
      );
    }).toList();
  }

  @override
  Future<void> saveProfile({
    required String name,
    required String avatar,
    required String city,
  }) => _db.collection('users').doc(_uid).set({
    'name': name,
    'avatar': avatar,
    'city': city,
  }, SetOptions(merge: true));
}
