import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/strings.dart';
import '../services/gamification.dart';
import '../services/share_service.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'about_screen.dart';
import 'areas_screen.dart';
import 'awards_screen.dart';
import 'checklist_screen.dart';
import 'leaderboard_screen.dart';
import 'profile_sheet.dart';
import 'settings_screen.dart';
import 'theme_screen.dart';
import 'tools_screen.dart';
import 'challenges_screen.dart';
import 'complaint_screen.dart';
import 'invite_screen.dart';
import 'motor_screen.dart';
import 'ranking_screen.dart';
import 'wrapped_screen.dart';

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    void open(Widget w) =>
        Navigator.push(context, MaterialPageRoute(builder: (_) => w));

    final features = <(String, String, Color, Widget?, VoidCallback?)>[
      (
        '🎁',
        'Bijli Wrapped',
        const Color(0xFFDB2777),
        const WrappedScreen(),
        null,
      ),
      (
        '🏅',
        'Challenges',
        const Color(0xFFF59E0B),
        const ChallengesScreen(),
        null,
      ),
      (
        '🏙️',
        'Area ranking',
        const Color(0xFF6366F1),
        const RankingScreen(),
        null,
      ),
      ('🏆', 'Leaderboard', BK.accent, const LeaderboardScreen(), null),
      ('🎖️', 'Badges', const Color(0xFFF59E0B), const AwardsScreen(), null),
      (
        '🔋',
        'UPS backup',
        const Color(0xFF22C55E),
        const ToolsScreen(initialTab: 0),
        null,
      ),
      (
        '☀️',
        'Solar planner',
        const Color(0xFFF97316),
        const ToolsScreen(initialTab: 1),
        null,
      ),
      (
        '🧾',
        'Bill estimate',
        const Color(0xFF0EA5E9),
        const ToolsScreen(initialTab: 2),
        null,
      ),
      (
        '📝',
        'Checklist',
        const Color(0xFFA855F7),
        const ChecklistScreen(),
        null,
      ),
      ('🚰', 'Pump timer', const Color(0xFF0EA5E9), const MotorScreen(), null),
      (
        '📞',
        'Complaint',
        const Color(0xFFEF4444),
        const ComplaintScreen(),
        null,
      ),
      (
        '👨‍👩‍👧',
        'Invite friends',
        const Color(0xFF22C55E),
        const InviteScreen(),
        null,
      ),
      ('📍', 'My areas', const Color(0xFFEF4444), const AreasScreen(), null),
      ('🎨', 'Themes', const Color(0xFFEC4899), const ThemeScreen(), null),
      ('🔔', 'Alerts', const Color(0xFF14B8A6), const SettingsScreen(), null),
      (
        '📲',
        'Share app',
        const Color(0xFF6366F1),
        null,
        () async {
          await ShareService.shareApp();
          app.countShare();
        },
      ),
      (
        '⭐',
        'Rate us',
        const Color(0xFFEAB308),
        null,
        () {
          launchUrl(
            Uri.parse(kPlayStoreUrl),
            mode: LaunchMode.externalApplication,
          );
        },
      ),
      (
        'ℹ️',
        'How it works',
        const Color(0xFF64748B),
        const AboutScreen(),
        null,
      ),
    ];

    return BScaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 30),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    tr('More'),
                    style: TextStyle(
                      color: BK.txt,
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.settings_rounded, color: BK.muted),
                  onPressed: () => open(const SettingsScreen()),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _ProfileCard(onEdit: () => showProfileSheet(context)),
            const SectionTitle('Features'),
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 0.98,
              children: [
                for (final (emoji, label, color, page, action) in features)
                  GlassCard(
                    padding: const EdgeInsets.all(10),
                    radius: 20,
                    onTap: action ?? () => open(page!),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        EmojiBox(emoji, color: color, size: 48),
                        const SizedBox(height: 8),
                        Text(
                          tr(label),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          style: TextStyle(
                            color: BK.txt,
                            fontWeight: FontWeight.w700,
                            fontSize: 12.5,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  final VoidCallback onEdit;
  const _ProfileCard({required this.onEdit});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final lv = levelFor(app.totalPoints);
    final nx = nextLevel(app.totalPoints);
    final progress = nx == null
        ? 1.0
        : (app.totalPoints - lv.minPoints) / (nx.minPoints - lv.minPoints);
    return GlassCard(
      gradient: LinearGradient(
        colors: [
          BK.accent.withValues(alpha: 0.25),
          BK.accent2.withValues(alpha: 0.10),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      glow: BK.accent,
      onTap: onEdit,
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 64,
                height: 64,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: BK.accentGradient,
                ),
                child: Text(app.avatar, style: const TextStyle(fontSize: 34)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      app.name.isEmpty ? tr('Set your name') : app.name,
                      style: TextStyle(
                        color: BK.txt,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${lv.emoji} ${tr(lv.title)} · ${trf('Level {0}', [lv.number])}',
                      style: TextStyle(
                        color: BK.accent,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.edit_rounded, color: BK.muted, size: 20),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              minHeight: 9,
              backgroundColor: BK.panel2,
              valueColor: AlwaysStoppedAnimation(BK.accent),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Text(
                trf('{0} points', [app.totalPoints]),
                style: TextStyle(
                  color: BK.txt,
                  fontWeight: FontWeight.w800,
                  fontSize: 12.5,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  nx == null
                      ? tr('Max level!')
                      : trf('{0} more to {1}', [
                          nx.minPoints - app.totalPoints,
                          tr(nx.title),
                        ]),
                  textAlign: TextAlign.end,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: BK.muted, fontSize: 12.5),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: StatBlock('${app.reportCount}', tr('reports'))),
              Expanded(child: StatBlock('${app.firsts}', tr('first reports'))),
              Expanded(child: StatBlock('${app.streak}🔥', tr('day streak'))),
              Expanded(
                child: StatBlock(
                  '${app.earnedAwards.length}/${kAwards.length}',
                  tr('badges'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
