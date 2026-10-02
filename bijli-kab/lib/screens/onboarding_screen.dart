import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/strings.dart';
import '../models/models.dart';
import '../services/notification_service.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/power_orb.dart';
import 'area_picker_screen.dart';
import 'profile_sheet.dart';

/// Language → welcome → features → area → profile → alerts.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pages = PageController();
  int _page = 0;
  static const _count = 6;

  void _next() {
    if (_page < _count - 1) {
      _pages.nextPage(
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    return BScaffold(
      sparks: _page < 3,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Row(
                children: [
                  if (_page > 0)
                    IconButton(
                      icon: Icon(Icons.arrow_back_rounded, color: BK.muted),
                      onPressed: () => _pages.previousPage(
                        duration: const Duration(milliseconds: 350),
                        curve: Curves.easeOut,
                      ),
                    )
                  else
                    const SizedBox(width: 48),
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        for (var i = 0; i < _count; i++)
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            width: i == _page ? 24 : 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: i <= _page ? BK.accent : BK.line,
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),
            Expanded(
              child: PageView(
                controller: _pages,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (i) => setState(() => _page = i),
                children: [
                  _LanguagePage(onNext: _next),
                  _WelcomePage(onNext: _next),
                  _FeaturesPage(onNext: _next),
                  _AreaPage(
                    onDone: (a) async {
                      await app.addArea(a);
                      _next();
                    },
                  ),
                  _ProfilePage(onNext: _next),
                  _AlertsPage(onDone: app.completeOnboarding),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Page extends StatelessWidget {
  final List<Widget> children;
  final Widget? bottom;
  const _Page({required this.children, this.bottom});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
    child: Column(
      children: [
        Expanded(
          child: SingleChildScrollView(child: Column(children: children)),
        ),
        ?bottom,
      ],
    ),
  );
}

TextStyle get _h1 => TextStyle(
  color: BK.txt,
  fontSize: 30,
  fontWeight: FontWeight.w900,
  height: 1.15,
);
TextStyle get _p => TextStyle(color: BK.muted, fontSize: 15.5, height: 1.45);

class _LanguagePage extends StatelessWidget {
  final VoidCallback onNext;
  const _LanguagePage({required this.onNext});
  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    return _Page(
      bottom: GradientButton(label: tr('Continue'), onPressed: onNext),
      children: [
        const SizedBox(height: 30),
        const Text('🌐', style: TextStyle(fontSize: 60)),
        const SizedBox(height: 12),
        Text(
          'Zubaan chunein\nChoose language',
          textAlign: TextAlign.center,
          style: _h1,
        ),
        const SizedBox(height: 26),
        for (final l in kLanguages)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: GlassCard(
              glow: app.lang == l.code ? BK.accent : null,
              onTap: () => app.setLang(l.code),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l.name,
                          style: TextStyle(
                            color: BK.txt,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          l.hint,
                          style: TextStyle(color: BK.muted, fontSize: 12.5),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    app.lang == l.code
                        ? Icons.radio_button_checked_rounded
                        : Icons.radio_button_off_rounded,
                    color: app.lang == l.code ? BK.accent : BK.muted,
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _WelcomePage extends StatelessWidget {
  final VoidCallback onNext;
  const _WelcomePage({required this.onNext});
  @override
  Widget build(BuildContext context) => _Page(
    bottom: GradientButton(label: tr('Let\'s start'), onPressed: onNext),
    children: [
      const SizedBox(height: 10),
      const PowerOrb(state: PowerState.on, size: 240),
      const SizedBox(height: 10),
      ShaderMask(
        shaderCallback: (r) => BK.accentGradient.createShader(r),
        child: const Text(
          'Bijli Kab?',
          style: TextStyle(
            color: Colors.white,
            fontSize: 46,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
      const SizedBox(height: 10),
      Text(
        tr('Know when the light will go — before it goes.'),
        textAlign: TextAlign.center,
        style: TextStyle(
          color: BK.txt,
          fontSize: 19,
          fontWeight: FontWeight.w700,
        ),
      ),
      const SizedBox(height: 12),
      Text(
        tr(
          'Powered by your neighbours. One tap from you helps your whole street.',
        ),
        textAlign: TextAlign.center,
        style: _p,
      ),
    ],
  );
}

class _FeaturesPage extends StatelessWidget {
  final VoidCallback onNext;
  const _FeaturesPage({required this.onNext});
  @override
  Widget build(BuildContext context) {
    final items = [
      (
        '⚡',
        'One-tap reports',
        'Light gayi? Light aayi? Tell your area in one second.',
        BK.accent,
      ),
      (
        '🔮',
        'Smart forecast',
        'Learns your area\'s loadshedding pattern and predicts the next cut.',
        const Color(0xFFA855F7),
      ),
      (
        '🔔',
        'Alerts',
        'Get warned before the cut — charge the phone, fill the water.',
        const Color(0xFF14B8A6),
      ),
      (
        '🗺️',
        'Live map',
        'See which areas around you have light right now.',
        const Color(0xFF0EA5E9),
      ),
      (
        '🏆',
        'Points & badges',
        'Climb the leaderboard and become the Mohalla Hero.',
        const Color(0xFFF59E0B),
      ),
      (
        '🔋',
        'Power tools',
        'UPS backup, solar planner and bill estimate.',
        const Color(0xFF22C55E),
      ),
    ];
    return _Page(
      bottom: GradientButton(label: tr('Continue'), onPressed: onNext),
      children: [
        const SizedBox(height: 10),
        Text(
          tr('Everything in one app'),
          textAlign: TextAlign.center,
          style: _h1,
        ),
        const SizedBox(height: 20),
        for (final (e, t, d, c) in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: GlassCard(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  EmojiBox(e, color: c, size: 48),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tr(t),
                          style: TextStyle(
                            color: BK.txt,
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          tr(d),
                          style: TextStyle(
                            color: BK.muted,
                            fontSize: 13,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _AreaPage extends StatelessWidget {
  final ValueChanged<SavedArea> onDone;
  const _AreaPage({required this.onDone});
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 12),
        child: Column(
          children: [
            Text(
              tr('Where is your home?'),
              textAlign: TextAlign.center,
              style: _h1,
            ),
            const SizedBox(height: 6),
            Text(
              tr(
                'We only use it to know your area (~1 km). Your exact location stays on your phone.',
              ),
              textAlign: TextAlign.center,
              style: _p.copyWith(fontSize: 13.5),
            ),
          ],
        ),
      ),
      Expanded(
        child: AreaPickerScreen(
          embedded: true,
          defaultLabel: tr('Ghar'),
          onDone: onDone,
        ),
      ),
    ],
  );
}

class _ProfilePage extends StatelessWidget {
  final VoidCallback onNext;
  const _ProfilePage({required this.onNext});
  @override
  Widget build(BuildContext context) => _Page(
    children: [
      const SizedBox(height: 10),
      Text(
        tr('Pick your reporter name'),
        textAlign: TextAlign.center,
        style: _h1,
      ),
      const SizedBox(height: 6),
      Text(
        tr('Shown on the leaderboard. Any nickname works.'),
        textAlign: TextAlign.center,
        style: _p,
      ),
      const SizedBox(height: 22),
      ProfileEditor(inline: true, onSaved: onNext),
    ],
  );
}

class _AlertsPage extends StatefulWidget {
  final Future<void> Function() onDone;
  const _AlertsPage({required this.onDone});
  @override
  State<_AlertsPage> createState() => _AlertsPageState();
}

class _AlertsPageState extends State<_AlertsPage> {
  bool _busy = false;
  @override
  Widget build(BuildContext context) => _Page(
    bottom: Column(
      children: [
        GradientButton(
          label: tr('Allow alerts'),
          icon: Icons.notifications_active_rounded,
          busy: _busy,
          onPressed: () async {
            setState(() => _busy = true);
            await NotificationService.requestPermission();
            await widget.onDone();
          },
        ),
        TextButton(
          onPressed: () async {
            await context.read<AppState>().setAlerts(
              predict: false,
              liveChanges: false,
            );
            await widget.onDone();
          },
          child: Text(tr('Not now'), style: TextStyle(color: BK.muted)),
        ),
      ],
    ),
    children: [
      const SizedBox(height: 40),
      const Text('🔔', style: TextStyle(fontSize: 90)),
      const SizedBox(height: 16),
      Text(
        tr('Never get caught in the dark'),
        textAlign: TextAlign.center,
        style: _h1,
      ),
      const SizedBox(height: 12),
      Text(
        tr(
          'We will warn you 15 minutes before a likely cut and tell you when the light comes back.',
        ),
        textAlign: TextAlign.center,
        style: _p,
      ),
    ],
  );
}
