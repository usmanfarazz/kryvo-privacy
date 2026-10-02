/// Weekly challenges: three per week, picked from a pool, same for everyone.
library;

/// What a challenge counts during the week.
enum ChallengeKind { reports, firsts, days, guessWins, shares, details, moods }

class Challenge {
  final String id;
  final String emoji;
  final String title; // "{0}" = target
  final ChallengeKind kind;
  final int target;
  final int reward;
  const Challenge(
    this.id,
    this.emoji,
    this.title,
    this.kind,
    this.target,
    this.reward,
  );
}

const kChallengePool = [
  Challenge('r10', '📣', 'Send {0} reports', ChallengeKind.reports, 10, 60),
  Challenge('r20', '📢', 'Send {0} reports', ChallengeKind.reports, 20, 120),
  Challenge(
    'f2',
    '🚨',
    'Be first to report {0} times',
    ChallengeKind.firsts,
    2,
    80,
  ),
  Challenge(
    'd5',
    '🔥',
    'Report on {0} different days',
    ChallengeKind.days,
    5,
    90,
  ),
  Challenge('g1', '🎯', 'Win {0} guess game', ChallengeKind.guessWins, 1, 70),
  Challenge('g3', '🏹', 'Win {0} guess games', ChallengeKind.guessWins, 3, 150),
  Challenge('s1', '📲', 'Share {0} time', ChallengeKind.shares, 1, 40),
  Challenge(
    'x3',
    '🔍',
    'Add a detail to {0} reports',
    ChallengeKind.details,
    3,
    60,
  ),
  Challenge(
    'm5',
    '😩',
    'React to your area\'s mood {0} times',
    ChallengeKind.moods,
    5,
    40,
  ),
];

/// Monday of the week containing [t], at midnight.
DateTime weekStart(DateTime t) {
  final d = DateTime(t.year, t.month, t.day);
  return d.subtract(Duration(days: d.weekday - 1));
}

/// "2026-10-05" — the Monday, used as the week's key.
String weekKey(DateTime t) {
  final m = weekStart(t);
  return '${m.year}-${m.month.toString().padLeft(2, '0')}-${m.day.toString().padLeft(2, '0')}';
}

/// The three challenges of the week of [t] (deterministic).
List<Challenge> challengesFor(DateTime t) {
  final weekNo = weekStart(t).millisecondsSinceEpoch ~/ (7 * 86400000);
  final picked = <Challenge>[];
  final kinds = <ChallengeKind>{};
  var i = weekNo * 5;
  while (picked.length < 3) {
    final c = kChallengePool[i % kChallengePool.length];
    if (kinds.add(c.kind)) picked.add(c);
    i += 3;
  }
  return picked;
}
