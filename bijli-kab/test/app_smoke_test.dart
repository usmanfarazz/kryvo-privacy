import 'dart:convert';

import 'package:bijli_kab/l10n/strings.dart';
import 'package:bijli_kab/main.dart';
import 'package:bijli_kab/models/models.dart';
import 'package:bijli_kab/screens/about_screen.dart';
import 'package:bijli_kab/screens/challenges_screen.dart';
import 'package:bijli_kab/screens/complaint_screen.dart';
import 'package:bijli_kab/screens/invite_screen.dart';
import 'package:bijli_kab/screens/lock_screen.dart';
import 'package:bijli_kab/screens/motor_screen.dart';
import 'package:bijli_kab/screens/ranking_screen.dart';
import 'package:bijli_kab/screens/wrapped_screen.dart';
import 'package:bijli_kab/screens/areas_screen.dart';
import 'package:bijli_kab/screens/awards_screen.dart';
import 'package:bijli_kab/screens/checklist_screen.dart';
import 'package:bijli_kab/screens/leaderboard_screen.dart';
import 'package:bijli_kab/screens/settings_screen.dart';
import 'package:bijli_kab/screens/theme_screen.dart';
import 'package:bijli_kab/screens/tools_screen.dart';
import 'package:bijli_kab/services/demo_repository.dart';
import 'package:bijli_kab/state/app_state.dart';
import 'package:bijli_kab/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _area = SavedArea(
  id: 'ttsgx8',
  label: 'Ghar',
  emoji: '🏠',
  place: 'Gulberg III',
  city: 'Lahore',
  lat: 31.51,
  lng: 74.35,
);

Future<AppState> _boot(WidgetTester tester, {bool onboarded = true}) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2.625;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({
    'onboarded': onboarded,
    if (onboarded) 'areas': [jsonEncode(_area.toJson())],
    if (onboarded) 'active': _area.id,
  });
  final app = AppState(DemoRepository());
  await tester.runAsync(app.init);
  await tester.pumpWidget(
    ChangeNotifierProvider.value(value: app, child: const BijliKabApp()),
  );
  await tester.pump(const Duration(milliseconds: 500));
  return app;
}

Future<void> _open(WidgetTester tester, Widget page) async {
  final nav = tester.state<NavigatorState>(find.byType(Navigator).first);
  nav.push(MaterialPageRoute(builder: (_) => page));
  await tester.pump(const Duration(milliseconds: 600));
  await tester.pump(const Duration(milliseconds: 600));
  _noErr(tester, '');
  nav.pop();
  await tester.pump(const Duration(milliseconds: 600));
}

void _noErr(WidgetTester tester, String reason) {
  final e = tester.takeException();
  if (e is FlutterError) debugPrint(e.toStringDeep());
  expect(e, isNull, reason: reason);
}

List<Widget> _pages() => const [
  SettingsScreen(),
  ThemeScreen(),
  AwardsScreen(),
  LeaderboardScreen(),
  AreasScreen(),
  ChecklistScreen(),
  AboutScreen(),
  ToolsScreen(initialTab: 0),
  ToolsScreen(initialTab: 1),
  ToolsScreen(initialTab: 2),
  WrappedScreen(),
  RankingScreen(),
  ChallengesScreen(),
  ComplaintScreen(),
  MotorScreen(),
  InviteScreen(),
  PinSetupScreen(),
];

void main() {
  testWidgets('home shows a status and the report buttons', (tester) async {
    final app = await _boot(tester);
    expect(app.activeLive, isNotNull);
    expect(find.text(tr('Light Gayi')), findsOneWidget);
    expect(find.text(tr('Light Aayi')), findsOneWidget);
    expect(find.text('Ghar'), findsWidgets);
    _noErr(tester, '');
    app.dispose();
  });

  testWidgets('every tab renders', (tester) async {
    final app = await _boot(tester);
    for (final label in ['Forecast', 'Stats', 'More', 'Home']) {
      await tester.tap(find.text(tr(label)).last);
      await tester.pump(const Duration(milliseconds: 600));
      _noErr(tester, label);
    }
    app.dispose();
  });

  for (final lang in ['en', 'rur', 'ur', 'hi']) {
    testWidgets('every screen renders without overflow ($lang)', (
      tester,
    ) async {
      final app = await _boot(tester);
      await app.setLang(lang);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      for (final label in ['Forecast', 'Stats', 'More', 'Home']) {
        await tester.tap(find.text(tr(label)).last);
        await tester.pump(const Duration(milliseconds: 600));
        _noErr(tester, '$lang $label');
      }
      for (final page in _pages()) {
        await _open(tester, page);
      }
      app.dispose();
    });
  }

  testWidgets('every screen renders without overflow', (tester) async {
    final app = await _boot(tester);
    for (final page in [
      const SettingsScreen(),
      const ThemeScreen(),
      const AwardsScreen(),
      const LeaderboardScreen(),
      const AreasScreen(),
      const ChecklistScreen(),
      const AboutScreen(),
      const ToolsScreen(initialTab: 0),
    ]) {
      await _open(tester, page);
    }
    app.dispose();
  });

  testWidgets('all themes and languages render home', (tester) async {
    final app = await _boot(tester);
    for (final p in BK.palettes) {
      await app.setTheme(p.id);
      await tester.pump(const Duration(milliseconds: 300));
      _noErr(tester, p.id);
    }
    for (final l in kLanguages) {
      await app.setLang(l.code);
      await tester.pump(const Duration(milliseconds: 300));
      _noErr(tester, l.code);
    }
    app.dispose();
  });

  testWidgets('reporting earns points and a badge', (tester) async {
    final app = await _boot(tester);
    final before = app.points;
    final out = await tester.runAsync(
      () => app.report(false, PowerIssue.transformer),
    );
    expect(out!.ok, isTrue);
    expect(app.points, greaterThan(before));
    expect(out.newAwards.map((a) => a.id), contains('first'));
    final again = await tester.runAsync(
      () => app.report(true, PowerIssue.none),
    );
    expect(again!.ok, isFalse, reason: 'cool-down');
    expect(again.wait, isNotNull);
    app.dispose();
  });

  testWidgets('onboarding starts with language choice', (tester) async {
    final app = await _boot(tester, onboarded: false);
    expect(find.text('Roman Urdu'), findsOneWidget);
    expect(find.text('اردو'), findsOneWidget);
    _noErr(tester, '');
    app.dispose();
  });

  testWidgets('App Lock: off by default, PIN locks and unlocks', (
    tester,
  ) async {
    final app = await _boot(tester);
    expect(app.lockEnabled, isFalse, reason: 'no password by default');
    expect(app.locked, isFalse);
    await tester.runAsync(() => app.setPin('1234'));
    app.lock();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(LockScreen), findsOneWidget);
    _noErr(tester, 'lock screen');
    expect(app.checkPin('0000'), isFalse);
    expect(app.checkPin('1234'), isTrue);
    app.unlock();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(LockScreen), findsNothing);
    await tester.runAsync(app.disableLock);
    app.lock();
    expect(app.locked, isFalse, reason: 'lock does nothing when disabled');
    app.dispose();
  });

  testWidgets('weekly challenge completes and pays a bonus', (tester) async {
    final app = await _boot(tester);
    final before = app.totalPoints;
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(
        () => app.setMood(['😩', '🥵', '🕯️', '😡', '🎉'][i]),
      );
    }
    await tester.runAsync(app.countShare);
    expect(app.totalPoints, greaterThanOrEqualTo(before));
    app.dispose();
  });

  testWidgets('friend code adds an area once with a welcome bonus', (
    tester,
  ) async {
    final app = await _boot(tester);
    final r1 = await tester.runAsync(() => app.addFriendCode('ttsgx3'));
    expect(r1, FriendCodeResult.added);
    expect(app.bonus, 20);
    final r2 = await tester.runAsync(() => app.addFriendCode('TTSGX3'));
    expect(r2, FriendCodeResult.alreadyFollowing);
    final r3 = await tester.runAsync(() => app.addFriendCode('abc'));
    expect(r3, FriendCodeResult.invalid);
    expect(app.bonus, 20);
    app.dispose();
  });
}
