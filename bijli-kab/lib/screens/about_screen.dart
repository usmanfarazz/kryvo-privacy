import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/strings.dart';
import '../services/share_service.dart';
import '../theme.dart';
import '../widgets/common.dart';

const kSupportEmail = 'usmanfaraz1818@gmail.com';
const kPrivacyUrl = 'https://usmanfarazz.github.io/bijli-kab/privacy.html';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final steps = [
      ('👆', 'You tap', 'Light Gayi or Light Aayi — takes one second.'),
      (
        '🏘️',
        'Neighbours confirm',
        'Reports from the same ~1 km area are combined. A single wrong tap is out-voted.',
      ),
      (
        '🧠',
        'The app learns',
        'After a few days it learns when cuts usually happen in your area.',
      ),
      (
        '🔔',
        'Everyone gets warned',
        'Alerts before the next cut and when the light comes back.',
      ),
    ];
    return BScaffold(
      title: 'How it works',
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 30),
        children: [
          Center(
            child: Column(
              children: [
                Container(
                  width: 92,
                  height: 92,
                  decoration: BoxDecoration(
                    gradient: BK.accentGradient,
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: BK.accent.withValues(alpha: 0.45),
                        blurRadius: 30,
                      ),
                    ],
                  ),
                  child: Icon(Icons.bolt_rounded, size: 64, color: BK.onAccent),
                ),
                const SizedBox(height: 12),
                Text(
                  'Bijli Kab?',
                  style: TextStyle(
                    color: BK.txt,
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  tr('Know before the light goes'),
                  style: TextStyle(color: BK.muted),
                ),
                const SizedBox(height: 4),
                Text(
                  'v1.0.0 · Faraz Labs',
                  style: TextStyle(color: BK.muted, fontSize: 12),
                ),
              ],
            ),
          ),
          const SectionTitle('How it works'),
          for (final (i, (e, t, d)) in steps.indexed)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: GlassCard(
                padding: const EdgeInsets.all(14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    EmojiBox(e),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${i + 1}. ${tr(t)}',
                            style: TextStyle(
                              color: BK.txt,
                              fontWeight: FontWeight.w900,
                              fontSize: 15.5,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            tr(d),
                            style: TextStyle(color: BK.muted, height: 1.35),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SectionTitle('Your privacy'),
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final t in [
                  'No phone number, email or real name needed.',
                  'Your exact location never leaves the phone — only the ~1 km area code is sent with a report.',
                  'Your nickname and points are public on the leaderboard; use any name you like.',
                  'No ads, no trackers. Delete everything any time from Settings.',
                ])
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.check_circle_rounded,
                          color: BK.on,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            tr(t),
                            style: TextStyle(color: BK.txt, height: 1.35),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          GlassCard(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Column(
              children: [
                BTile(
                  icon: Icons.privacy_tip_rounded,
                  title: 'Privacy policy',
                  onTap: () => launchUrl(
                    Uri.parse(kPrivacyUrl),
                    mode: LaunchMode.externalApplication,
                  ),
                ),
                BTile(
                  icon: Icons.mail_rounded,
                  title: 'Send feedback',
                  subtitle: kSupportEmail,
                  onTap: () => launchUrl(
                    Uri(
                      scheme: 'mailto',
                      path: kSupportEmail,
                      query: 'subject=Bijli Kab? feedback',
                    ),
                  ),
                ),
                BTile(
                  icon: Icons.star_rounded,
                  title: 'Rate on Play Store',
                  onTap: () => launchUrl(
                    Uri.parse(kPlayStoreUrl),
                    mode: LaunchMode.externalApplication,
                  ),
                ),
                BTile(
                  icon: Icons.share_rounded,
                  title: 'Share with friends',
                  onTap: ShareService.shareApp,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: Text(
              tr(
                'Forecasts are estimates from community reports, not official information.',
              ),
              textAlign: TextAlign.center,
              style: TextStyle(color: BK.muted, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
