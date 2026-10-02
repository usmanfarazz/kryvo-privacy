import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'firebase_options.dart';
import 'l10n/strings.dart';
import 'screens/lock_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/shell.dart';
import 'services/demo_repository.dart';
import 'services/firebase_repository.dart';
import 'services/repository.dart';
import 'state/app_state.dart';
import 'theme.dart';
import 'widgets/home_extras.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
    ),
  );
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  PowerRepository repo = DemoRepository();
  if (DefaultFirebaseOptions.isConfigured) {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      repo = FirebaseRepository();
    } catch (e) {
      debugPrint('Firebase init failed, demo mode: $e');
    }
  }

  runApp(
    ChangeNotifierProvider(
      create: (_) => AppState(repo)..init(),
      child: const BijliKabApp(),
    ),
  );
}

class BijliKabApp extends StatefulWidget {
  const BijliKabApp({super.key});

  @override
  State<BijliKabApp> createState() => _BijliKabAppState();
}

class _BijliKabAppState extends State<BijliKabApp> with WidgetsBindingObserver {
  String _look = '';
  final _messenger = GlobalKey<ScaffoldMessengerState>();
  int _seenCelebration = -1;
  bool _celebrating = false;
  DateTime? _pausedAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// App Lock: lock again after 30 s in the background.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _pausedAt = DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      final p = _pausedAt;
      _pausedAt = null;
      if (p != null && DateTime.now().difference(p).inSeconds >= 30) {
        context.read<AppState>().lock();
      }
    }
  }

  void _afterFrame(AppState app) {
    if (_seenCelebration < 0) _seenCelebration = app.celebrateTick;
    if (app.celebrateTick != _seenCelebration) {
      _seenCelebration = app.celebrateTick;
      setState(() => _celebrating = true);
    }
    while (app.justCompleted.isNotEmpty) {
      final c = app.justCompleted.removeAt(0);
      _messenger.currentState?.showSnackBar(
        SnackBar(
          content: Text(
            '${c.emoji} ${tr('Challenge complete!')} +${c.reward} ${tr('points')}',
          ),
        ),
      );
    }
  }

  /// Colours and texts are read from static getters (BK, tr), and const
  /// widgets don't rebuild on their own. After a theme or language change,
  /// mark the whole tree dirty — screens and navigation stay where they are.
  void _rebuildEverything() {
    void mark(Element e) {
      e.markNeedsBuild();
      e.visitChildren(mark);
    }

    if (mounted) (context as Element).visitChildren(mark);
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final look = '${app.lang}|${app.themeId}';
    if (_look.isNotEmpty && look != _look) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _rebuildEverything());
    }
    _look = look;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _afterFrame(app);
    });
    final locale = switch (app.lang) {
      'ur' => const Locale('ur'),
      'hi' => const Locale('hi'),
      _ => const Locale('en'),
    };
    return MaterialApp(
      title: 'Bijli Kab?',
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: _messenger,
      theme: BK.theme(),
      locale: locale,
      supportedLocales: const [Locale('en'), Locale('ur'), Locale('hi')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      builder: (context, child) {
        SystemChrome.setSystemUIOverlayStyle(
          SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: BK.dark
                ? Brightness.light
                : Brightness.dark,
            systemNavigationBarColor: BK.panel,
            systemNavigationBarIconBrightness: BK.dark
                ? Brightness.light
                : Brightness.dark,
          ),
        );
        return Directionality(
          textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
          child: Stack(
            children: [
              child!,
              if (_celebrating)
                Positioned.fill(
                  child: CelebrationOverlay(
                    onDone: () {
                      if (mounted) setState(() => _celebrating = false);
                    },
                  ),
                ),
              if (app.ready && app.locked)
                const Positioned.fill(child: LockScreen()),
            ],
          ),
        );
      },
      home: !app.ready
          ? const _Splash()
          : (app.onboarded && app.areas.isNotEmpty)
          ? const Shell()
          : const OnboardingScreen(),
    );
  }
}

class _Splash extends StatelessWidget {
  const _Splash();
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: BK.bg,
    body: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ShaderMask(
            shaderCallback: (r) => BK.accentGradient.createShader(r),
            child: const Icon(
              Icons.bolt_rounded,
              size: 96,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Bijli Kab?',
            style: TextStyle(
              color: BK.txt,
              fontSize: 30,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    ),
  );
}
