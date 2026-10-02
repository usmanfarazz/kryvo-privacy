import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/format.dart';
import '../l10n/strings.dart';
import '../services/share_service.dart';
import '../services/status_engine.dart';
import '../state/app_state.dart';

/// "Bijli Wrapped": story-style slides about the last 4 weeks.
class WrappedScreen extends StatefulWidget {
  const WrappedScreen({super.key});
  @override
  State<WrappedScreen> createState() => _WrappedScreenState();
}

class _Slide {
  final String emoji, kicker, big, line;
  final List<Color> colors;
  const _Slide(this.emoji, this.kicker, this.big, this.line, this.colors);
}

class _WrappedScreenState extends State<WrappedScreen> {
  final _pages = PageController();
  final _shareKey = GlobalKey();
  int _page = 0;
  Timer? _auto;

  @override
  void initState() {
    super.initState();
    _auto = Timer.periodic(const Duration(seconds: 5), (_) => _next());
  }

  @override
  void dispose() {
    _auto?.cancel();
    _pages.dispose();
    super.dispose();
  }

  void _next() {
    if (!mounted || !_pages.hasClients) return;
    final count = _slides(context.read<AppState>()).length;
    if (_page < count - 1) {
      _pages.nextPage(
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeOutCubic,
      );
    } else {
      _auto?.cancel();
    }
  }

  List<_Slide> _slides(AppState app) {
    final l = app.activeLive;
    final now = DateTime.now();
    if (l == null || l.observedDays < 3) {
      return [
        _Slide(
          '⏳',
          tr('Bijli Wrapped'),
          tr('Coming soon'),
          tr(
            'Your Wrapped is ready after 3 days of reports in your area. Keep reporting!',
          ),
          const [Color(0xFF6D28D9), Color(0xFFDB2777)],
        ),
      ];
    }
    final firstDay = (28 - l.observedDays).clamp(0, 27);
    final outs = l.outages;
    final from = now.subtract(const Duration(days: 28));
    final mid = now.subtract(const Duration(days: 14));
    final total = StatusEngine.offBetween(outs, from, now).inMinutes / 60;
    final recent = StatusEngine.offBetween(outs, mid, now).inMinutes / 60;
    final older = StatusEngine.offBetween(outs, from, mid).inMinutes / 60;
    final cuts = outs.where((o) => o.end.isAfter(from)).toList();
    final longest = cuts.fold<Duration>(
      Duration.zero,
      (m, o) => o.duration > m ? o.duration : m,
    );
    final profile = StatusEngine.hourOfDayProfile(outs, now, 28);
    var worstHour = 0;
    for (var h = 1; h < 24; h++) {
      if (profile[h] > profile[worstHour]) worstHour = h;
    }
    final daily = StatusEngine.dailyOffHours(outs, now, 28);
    var best = firstDay;
    for (var i = firstDay + 1; i < daily.length - 1; i++) {
      if (daily[i] < daily[best]) best = i;
    }
    final bestDay = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: daily.length - 1 - best));
    final pctOn = (100 - total / (28 * 24) * 100).clamp(0, 100).round();
    final area = app.active?.title ?? '';
    final change = older == 0 ? 0 : ((recent - older) / older * 100).round();

    return [
      _Slide(
        '🎁',
        tr('Bijli Wrapped'),
        area,
        tr('Your last 4 weeks with the light. Tap to continue →'),
        const [Color(0xFF6D28D9), Color(0xFFDB2777)],
      ),
      _Slide(
        '🕯️',
        tr('Total time without light'),
        fmtHours(total),
        trf('That\'s {0} full days in the dark.', [
          (total / 24).toStringAsFixed(1),
        ]),
        const [Color(0xFFB91C1C), Color(0xFF7C2D12)],
      ),
      _Slide(
        '✂️',
        tr('Power cuts'),
        '${cuts.length}',
        trf('The longest one lasted {0}.', [fmtDuration(longest)]),
        const [Color(0xFFEA580C), Color(0xFFCA8A04)],
      ),
      _Slide(
        '⏰',
        tr('Worst hour'),
        hourLabel(worstHour),
        tr('The light went most often around this time.'),
        const [Color(0xFF0F766E), Color(0xFF1D4ED8)],
      ),
      _Slide(
        change <= 0 ? '📉' : '📈',
        tr('Last 2 weeks vs before'),
        change == 0 ? '=' : '${change > 0 ? '+' : ''}$change%',
        change <= 0
            ? tr('Less loadshedding lately. 🙏')
            : tr('More loadshedding lately. 😤'),
        change <= 0
            ? const [Color(0xFF15803D), Color(0xFF0E7490)]
            : const [Color(0xFF9F1239), Color(0xFF7E22CE)],
      ),
      _Slide(
        '🌟',
        tr('Best day'),
        fmtDay(bestDay),
        trf('{0} — only {1} without light.', [
          '${bestDay.day}/${bestDay.month}',
          fmtHours(daily[best]),
        ]),
        const [Color(0xFF0369A1), Color(0xFF4F46E5)],
      ),
      _Slide(
        app.level.emoji,
        tr('You as a reporter'),
        '${app.totalPoints}',
        trf('{0} reports · {1} first reports · {2} badges · {3} guesses won', [
          app.reportCount,
          app.firsts,
          app.earnedAwards.length,
          app.guessWins,
        ]),
        const [Color(0xFFCA8A04), Color(0xFFEA580C)],
      ),
      _Slide(
        '💡',
        tr('Light was on'),
        '$pctOn%',
        tr('Share your Wrapped and see your friends\' too!'),
        const [Color(0xFF15803D), Color(0xFFCA8A04)],
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final slides = _slides(app);
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            GestureDetector(
              onTapUp: (d) {
                _auto?.cancel();
                final w = MediaQuery.of(context).size.width;
                if (d.localPosition.dx < w * 0.3 && _page > 0) {
                  _pages.previousPage(
                    duration: const Duration(milliseconds: 350),
                    curve: Curves.easeOut,
                  );
                } else {
                  _next();
                }
              },
              child: RepaintBoundary(
                key: _shareKey,
                child: PageView.builder(
                  controller: _pages,
                  itemCount: slides.length,
                  onPageChanged: (i) => setState(() => _page = i),
                  itemBuilder: (_, i) => _SlideView(slides[i]),
                ),
              ),
            ),
            Positioned(
              left: 12,
              right: 12,
              top: 10,
              child: Row(
                children: [
                  for (var i = 0; i < slides.length; i++)
                    Expanded(
                      child: Container(
                        height: 4,
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(
                            alpha: i <= _page ? 0.95 : 0.3,
                          ),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Positioned(
              right: 6,
              top: 20,
              child: IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            Positioned(
              left: 24,
              right: 24,
              bottom: 24,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                ),
                onPressed: () async {
                  _auto?.cancel();
                  final ok = await ShareService.shareWidget(
                    _shareKey,
                    trf('My Bijli Wrapped for {0} ⚡ #BijliKab', [
                      app.active?.title ?? '',
                    ]),
                  );
                  if (ok) app.countShare();
                },
                icon: const Icon(Icons.share_rounded),
                label: Text(tr('Share this')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SlideView extends StatelessWidget {
  final _Slide s;
  const _SlideView(this.s);
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: s.colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      padding: const EdgeInsets.fromLTRB(28, 70, 28, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.4, end: 1),
            duration: const Duration(milliseconds: 700),
            curve: Curves.elasticOut,
            builder: (_, v, child) => Transform.scale(
              scale: v,
              alignment: Alignment.centerLeft,
              child: child,
            ),
            child: Text(s.emoji, style: const TextStyle(fontSize: 72)),
          ),
          const SizedBox(height: 18),
          Text(
            s.kicker.toUpperCase(),
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 15,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.4,
            ),
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              s.big,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 76,
                height: 1.05,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            s.line,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              height: 1.35,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          const Row(
            children: [
              Icon(Icons.bolt_rounded, color: Color(0xFFFFD60A)),
              Text(
                'Bijli Kab?',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
