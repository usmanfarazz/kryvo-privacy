/// Points, levels and badges.
library;

class Points {
  static const report = 10;
  static const firstToReport = 25; // you announced the change for the area
  static const withDetail = 5; // added low voltage / transformer etc.
}

class Level {
  final int number;
  final String title;
  final String emoji;
  final int minPoints;
  const Level(this.number, this.title, this.emoji, this.minPoints);
}

const kLevels = [
  Level(1, 'Newcomer', '🔌', 0),
  Level(2, 'Spark', '✨', 50),
  Level(3, 'Reporter', '📣', 150),
  Level(4, 'Street Watch', '👀', 400),
  Level(5, 'Mohalla Hero', '🦸', 800),
  Level(6, 'Power Guru', '🧠', 1500),
  Level(7, 'Bijli Legend', '⚡', 3000),
];

Level levelFor(int points) => kLevels.lastWhere(
  (l) => points >= l.minPoints,
  orElse: () => kLevels.first,
);

Level? nextLevel(int points) {
  final i = kLevels.indexOf(levelFor(points));
  return i + 1 < kLevels.length ? kLevels[i + 1] : null;
}

/// Counters the badges are computed from.
class PlayerStats {
  final int points;
  final int reports;
  final int firsts;
  final int nightReports;
  final int detailReports;
  final int streak;
  final int areas;
  final int shares;
  const PlayerStats({
    this.points = 0,
    this.reports = 0,
    this.firsts = 0,
    this.nightReports = 0,
    this.detailReports = 0,
    this.streak = 0,
    this.areas = 0,
    this.shares = 0,
  });
}

class Award {
  final String id;
  final String emoji;
  final String title;
  final String description;
  final bool Function(PlayerStats s) earned;
  const Award(this.id, this.emoji, this.title, this.description, this.earned);
}

final kAwards = <Award>[
  Award(
    'first',
    '🎉',
    'First Report',
    'Send your first report',
    (s) => s.reports >= 1,
  ),
  Award('ten', '🔟', 'Regular', 'Send 10 reports', (s) => s.reports >= 10),
  Award('fifty', '🏅', 'Dedicated', 'Send 50 reports', (s) => s.reports >= 50),
  Award(
    'hundred',
    '💯',
    'Century',
    'Send 100 reports',
    (s) => s.reports >= 100,
  ),
  Award(
    'khabri',
    '📢',
    'Pehla Khabri',
    'Be first to report a change',
    (s) => s.firsts >= 1,
  ),
  Award(
    'khabri5',
    '🚨',
    'News Breaker',
    'Be first to report 5 times',
    (s) => s.firsts >= 5,
  ),
  Award(
    'night',
    '🦉',
    'Night Owl',
    'Report between midnight and 5 am',
    (s) => s.nightReports >= 1,
  ),
  Award(
    'detail',
    '🔍',
    'Detective',
    'Add details (low voltage, transformer…) 5 times',
    (s) => s.detailReports >= 5,
  ),
  Award(
    'streak3',
    '🔥',
    'On Fire',
    'Report 3 days in a row',
    (s) => s.streak >= 3,
  ),
  Award(
    'streak7',
    '🌋',
    'Unstoppable',
    'Report 7 days in a row',
    (s) => s.streak >= 7,
  ),
  Award('family', '🏘️', 'Family Watch', 'Follow 3 areas', (s) => s.areas >= 3),
  Award(
    'share',
    '📲',
    'Spread the Word',
    'Share your stats or the app',
    (s) => s.shares >= 1,
  ),
  Award(
    'legend',
    '⚡',
    'Bijli Legend',
    'Reach 3000 points',
    (s) => s.points >= 3000,
  ),
];
