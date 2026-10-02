import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/strings.dart';
import '../models/models.dart';
import '../services/gamification.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});
  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  bool _city = false;
  late Future<List<LeaderEntry>> _future = _load();

  Future<List<LeaderEntry>> _load() {
    final app = context.read<AppState>();
    return app.repo.leaderboard(city: _city ? app.primary?.city : null);
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final city = app.primary?.city ?? '';
    return BScaffold(
      title: 'Leaderboard',
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: SegmentedButton<bool>(
              segments: [
                ButtonSegment(value: false, label: Text(tr('Everyone'))),
                ButtonSegment(
                  value: true,
                  label: Text(city.isEmpty ? tr('My city') : city),
                ),
              ],
              selected: {_city},
              onSelectionChanged: (s) => setState(() {
                _city = s.first;
                _future = _load();
              }),
            ),
          ),
          Expanded(
            child: FutureBuilder<List<LeaderEntry>>(
              future: _future,
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return Center(
                    child: CircularProgressIndicator(color: BK.accent),
                  );
                }
                if (snap.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(30),
                      child: Text(
                        tr(
                          'Could not load the leaderboard. Check your internet.',
                        ),
                        textAlign: TextAlign.center,
                        style: TextStyle(color: BK.muted),
                      ),
                    ),
                  );
                }
                final list = snap.data ?? const [];
                if (list.isEmpty) {
                  return Center(
                    child: Text(
                      tr('No reporters yet. Be the first!'),
                      style: TextStyle(color: BK.muted),
                    ),
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async {
                    setState(() => _future = _load());
                    await _future;
                  },
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 30),
                    children: [
                      _Podium(top: list.take(3).toList(), me: app.repo.uid),
                      const SizedBox(height: 16),
                      for (final (i, e) in list.indexed)
                        if (i >= 3)
                          _Row(rank: i + 1, e: e, me: e.uid == app.repo.uid),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _Podium extends StatelessWidget {
  final List<LeaderEntry> top;
  final String me;
  const _Podium({required this.top, required this.me});

  @override
  Widget build(BuildContext context) {
    Widget col(int idx, double h, String medal, Color c) {
      if (idx >= top.length) return const Expanded(child: SizedBox());
      final e = top[idx];
      return Expanded(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(e.avatar, style: const TextStyle(fontSize: 36)),
            const SizedBox(height: 4),
            Text(
              e.uid == me ? tr('You') : e.name,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: BK.txt, fontWeight: FontWeight.w800),
            ),
            Text(
              '${e.points}',
              style: TextStyle(color: c, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            Container(
              height: h,
              margin: const EdgeInsets.symmetric(horizontal: 6),
              alignment: Alignment.topCenter,
              padding: const EdgeInsets.only(top: 8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [c, c.withValues(alpha: 0.35)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
              ),
              child: Text(medal, style: const TextStyle(fontSize: 28)),
            ),
          ],
        ),
      );
    }

    return SizedBox(
      height: 240,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          col(1, 90, '🥈', const Color(0xFFB0BEC5)),
          col(0, 125, '🥇', const Color(0xFFFFC107)),
          col(2, 70, '🥉', const Color(0xFFCD7F32)),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final int rank;
  final LeaderEntry e;
  final bool me;
  const _Row({required this.rank, required this.e, required this.me});
  @override
  Widget build(BuildContext context) {
    final lv = levelFor(e.points);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GlassCard(
        glow: me ? BK.accent : null,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            SizedBox(
              width: 30,
              child: Text(
                '#$rank',
                style: TextStyle(color: BK.muted, fontWeight: FontWeight.w900),
              ),
            ),
            Text(e.avatar, style: const TextStyle(fontSize: 28)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    me ? '${e.name} (${tr('You')})' : e.name,
                    style: TextStyle(
                      color: BK.txt,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    '${lv.emoji} ${tr(lv.title)} · ${trf('{0} reports', [e.reports])}',
                    style: TextStyle(color: BK.muted, fontSize: 12),
                  ),
                ],
              ),
            ),
            Text(
              '${e.points}',
              style: TextStyle(
                color: BK.accent,
                fontWeight: FontWeight.w900,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
