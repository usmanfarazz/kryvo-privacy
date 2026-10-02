import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/strings.dart';
import '../services/challenges.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';

class ChallengesScreen extends StatelessWidget {
  const ChallengesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final now = DateTime.now();
    final list = challengesFor(now);
    final end = weekStart(now).add(const Duration(days: 7));
    final left = end.difference(now);
    final done = list.where(app.isClaimed).length;
    return BScaffold(
      title: 'Weekly challenges',
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 30),
        children: [
          GlassCard(
            glow: BK.accent,
            gradient: LinearGradient(
              colors: [BK.accent.withValues(alpha: 0.22), BK.panel],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            child: Row(
              children: [
                const Text('🏅', style: TextStyle(fontSize: 42)),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        trf('{0} of {1} done this week', [done, list.length]),
                        style: TextStyle(
                          color: BK.txt,
                          fontSize: 19,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        trf('New challenges in {0} days {1} hours', [
                          left.inDays,
                          left.inHours % 24,
                        ]),
                        style: TextStyle(color: BK.muted, fontSize: 13),
                      ),
                      Text(
                        trf('Completed so far: {0}', [app.challengesDone]),
                        style: TextStyle(color: BK.muted, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          for (final c in list)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _ChallengeCard(c: c),
            ),
          const SizedBox(height: 8),
          Text(
            tr(
              'Challenges are the same for everyone and change every Monday. Rewards are added automatically.',
            ),
            style: TextStyle(color: BK.muted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _ChallengeCard extends StatelessWidget {
  final Challenge c;
  const _ChallengeCard({required this.c});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final p = app.weekProgress(c).clamp(0, c.target);
    final claimed = app.isClaimed(c);
    return GlassCard(
      glow: claimed ? BK.on : null,
      child: Column(
        children: [
          Row(
            children: [
              EmojiBox(c.emoji, size: 48),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      trf(c.title, [c.target]),
                      style: TextStyle(
                        color: BK.txt,
                        fontWeight: FontWeight.w900,
                        fontSize: 15.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      trf('Reward: +{0} points', [c.reward]),
                      style: TextStyle(
                        color: BK.accent,
                        fontWeight: FontWeight.w800,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
              if (claimed)
                Icon(Icons.check_circle_rounded, color: BK.on, size: 28)
              else
                Text(
                  '$p/${c.target}',
                  style: TextStyle(
                    color: BK.muted,
                    fontWeight: FontWeight.w900,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: p / c.target,
              minHeight: 8,
              backgroundColor: BK.panel2,
              valueColor: AlwaysStoppedAnimation(claimed ? BK.on : BK.accent),
            ),
          ),
        ],
      ),
    );
  }
}
