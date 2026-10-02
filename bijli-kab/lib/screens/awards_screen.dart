import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/strings.dart';
import '../services/gamification.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';

class AwardsScreen extends StatelessWidget {
  const AwardsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final earned = app.earnedAwards.map((a) => a.id).toSet();
    return BScaffold(
      title: 'Badges',
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 30),
        children: [
          GlassCard(
            glow: BK.accent,
            child: Row(
              children: [
                const Text('🎖️', style: TextStyle(fontSize: 42)),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        trf('{0} of {1} badges', [
                          earned.length,
                          kAwards.length,
                        ]),
                        style: TextStyle(
                          color: BK.txt,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        tr(
                          'Report, be first, keep a streak — collect them all!',
                        ),
                        style: TextStyle(color: BK.muted, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 0.8,
            children: [
              for (final a in kAwards)
                _AwardCard(award: a, earned: earned.contains(a.id)),
            ],
          ),
          const SectionTitle('Levels'),
          for (final l in kLevels)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: GlassCard(
                glow: app.level.number == l.number ? BK.accent : null,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    Text(l.emoji, style: const TextStyle(fontSize: 26)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '${trf('Level {0}', [l.number])} · ${tr(l.title)}',
                        style: TextStyle(
                          color: app.points >= l.minPoints ? BK.txt : BK.muted,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Text(
                      trf('{0} points', [l.minPoints]),
                      style: TextStyle(color: BK.muted, fontSize: 12.5),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _AwardCard extends StatelessWidget {
  final Award award;
  final bool earned;
  const _AwardCard({required this.award, required this.earned});
  @override
  Widget build(BuildContext context) {
    return GlassCard(
      glow: earned ? BK.accent : null,
      padding: const EdgeInsets.all(14),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Opacity(
            opacity: earned ? 1 : 0.3,
            child: ColorFiltered(
              colorFilter: earned
                  ? const ColorFilter.mode(Colors.transparent, BlendMode.dst)
                  : const ColorFilter.matrix([
                      0.33, 0.33, 0.33, 0, 0, //
                      0.33, 0.33, 0.33, 0, 0, //
                      0.33, 0.33, 0.33, 0, 0, //
                      0, 0, 0, 1, 0,
                    ]),
              child: Text(award.emoji, style: const TextStyle(fontSize: 44)),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            tr(award.title),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: earned ? BK.txt : BK.muted,
              fontWeight: FontWeight.w900,
              fontSize: 14.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            tr(award.description),
            textAlign: TextAlign.center,
            maxLines: 3,
            style: TextStyle(color: BK.muted, fontSize: 11.5),
          ),
          if (earned) ...[
            const SizedBox(height: 6),
            Icon(Icons.verified_rounded, color: BK.accent, size: 18),
          ],
        ],
      ),
    );
  }
}
