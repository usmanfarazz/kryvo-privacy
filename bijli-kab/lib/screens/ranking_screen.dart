import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/format.dart';
import '../l10n/strings.dart';
import '../models/models.dart';
import '../services/geohash.dart';
import '../services/share_service.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// Nearby areas ranked from the live map data: who is in the dark longest
/// right now, who has light, and which areas report most.
class RankingScreen extends StatefulWidget {
  const RankingScreen({super.key});
  @override
  State<RankingScreen> createState() => _RankingScreenState();
}

class _RankingScreenState extends State<RankingScreen> {
  late Future<List<AreaSnapshot>> _future = _load();

  Future<List<AreaSnapshot>> _load() {
    final app = context.read<AppState>();
    final a = app.primary;
    if (a == null) return Future.value(const []);
    return app.repo.nearby(a.id.substring(0, kNearbyPrecision));
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    return BScaffold(
      title: 'Area ranking',
      body: FutureBuilder<List<AreaSnapshot>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return Center(child: CircularProgressIndicator(color: BK.accent));
          }
          if (snap.hasError) {
            return Center(
              child: Text(
                tr('Could not load the map. Check your internet.'),
                style: TextStyle(color: BK.muted),
              ),
            );
          }
          final now = DateTime.now();
          final all = snap.data ?? const <AreaSnapshot>[];
          final dark =
              all
                  .where(
                    (a) => a.freshState == PowerState.off && a.since != null,
                  )
                  .toList()
                ..sort((a, b) => a.since!.compareTo(b.since!));
          final lit = all.where((a) => a.freshState == PowerState.on).length;
          final active = [...all]
            ..sort((a, b) => b.reports24h.compareTo(a.reports24h));
          final myId = app.primary?.id;
          return RefreshIndicator(
            onRefresh: () async {
              setState(() => _future = _load());
              await _future;
            },
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 30),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: GlassCard(
                        glow: BK.off,
                        child: StatBlock(
                          '${dark.length}',
                          tr('areas in the dark now'),
                          color: BK.off,
                          emoji: '🌑',
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: GlassCard(
                        glow: BK.on,
                        child: StatBlock(
                          '$lit',
                          tr('areas with light'),
                          color: BK.on,
                          emoji: '💡',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                GradientButton(
                  label: tr('Share ranking'),
                  icon: Icons.share_rounded,
                  onPressed: () {
                    final lines = [
                      '🌑 ${tr('Longest in the dark right now')}:',
                      for (final (i, a) in dark.take(5).indexed)
                        '${i + 1}. ${a.place} — ${fmtDuration(now.difference(a.since!))}',
                    ];
                    ShareService.shareText(lines.join('\n'));
                    app.countShare();
                  },
                ),
                const SectionTitle('Longest in the dark right now'),
                if (dark.isEmpty)
                  GlassCard(
                    child: Text(
                      tr('Everyone nearby has light right now 🎉'),
                      style: TextStyle(color: BK.muted),
                    ),
                  ),
                for (final (i, a) in dark.take(10).indexed)
                  _RankRow(
                    rank: i + 1,
                    title: a.place.isEmpty ? tr('Nearby area') : a.place,
                    value: fmtDuration(now.difference(a.since!)),
                    color: BK.off,
                    mine: a.id == myId,
                  ),
                const SectionTitle('Most active areas'),
                for (final (i, a) in active.take(10).indexed)
                  _RankRow(
                    rank: i + 1,
                    title: a.place.isEmpty ? tr('Nearby area') : a.place,
                    value: trf('{0} reports', [a.reports24h]),
                    color: BK.accent,
                    mine: a.id == myId,
                  ),
                const SizedBox(height: 10),
                Text(
                  tr('Based on the latest reports in each area around you.'),
                  style: TextStyle(color: BK.muted, fontSize: 12),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _RankRow extends StatelessWidget {
  final int rank;
  final String title, value;
  final Color color;
  final bool mine;
  const _RankRow({
    required this.rank,
    required this.title,
    required this.value,
    required this.color,
    required this.mine,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: GlassCard(
      glow: mine ? BK.accent : null,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          SizedBox(
            width: 34,
            child: Text(
              rank <= 3 ? ['🥇', '🥈', '🥉'][rank - 1] : '#$rank',
              style: TextStyle(
                color: BK.muted,
                fontWeight: FontWeight.w900,
                fontSize: rank <= 3 ? 20 : 14,
              ),
            ),
          ),
          Expanded(
            child: Text(
              mine ? '$title (${tr('You')})' : title,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: BK.txt, fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            value,
            style: TextStyle(color: color, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    ),
  );
}
