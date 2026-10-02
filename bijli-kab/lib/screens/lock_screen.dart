import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../l10n/strings.dart';
import '../services/app_lock.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// 4-digit PIN pad used by the lock screen and PIN setup.
class PinPad extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;
  final VoidCallback? onBiometric;
  final bool error;
  const PinPad({
    super.key,
    required this.value,
    required this.onChanged,
    this.onBiometric,
    this.error = false,
  });

  @override
  Widget build(BuildContext context) {
    Widget key(String label, {VoidCallback? onTap, Widget? child}) => Expanded(
      child: Padding(
        padding: const EdgeInsets.all(7),
        child: AspectRatio(
          aspectRatio: 1.35,
          child: Material(
            color: child == null && label.isEmpty
                ? Colors.transparent
                : BK.panel,
            borderRadius: BorderRadius.circular(20),
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: onTap,
              child: Center(
                child:
                    child ??
                    Text(
                      label,
                      style: TextStyle(
                        color: BK.txt,
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
              ),
            ),
          ),
        ),
      ),
    );

    void tap(String d) {
      if (value.length >= 4) return;
      HapticFeedback.selectionClick();
      onChanged(value + d);
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < 4; i++)
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                margin: const EdgeInsets.symmetric(horizontal: 10),
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: error
                      ? BK.off
                      : (i < value.length ? BK.accent : Colors.transparent),
                  border: Border.all(
                    color: error ? BK.off : BK.muted,
                    width: 2,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 26),
        for (final row in [
          ['1', '2', '3'],
          ['4', '5', '6'],
          ['7', '8', '9'],
        ])
          Row(children: [for (final d in row) key(d, onTap: () => tap(d))]),
        Row(
          children: [
            onBiometric == null
                ? key('')
                : key(
                    '',
                    onTap: onBiometric,
                    child: Icon(
                      Icons.fingerprint_rounded,
                      color: BK.accent,
                      size: 34,
                    ),
                  ),
            key('0', onTap: () => tap('0')),
            key(
              '',
              onTap: value.isEmpty
                  ? null
                  : () => onChanged(value.substring(0, value.length - 1)),
              child: Icon(Icons.backspace_outlined, color: BK.muted),
            ),
          ],
        ),
      ],
    );
  }
}

/// Shown over the app when App Lock is on.
class LockScreen extends StatefulWidget {
  const LockScreen({super.key});
  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  String _pin = '';
  bool _error = false;
  bool _bioAvailable = false;

  @override
  void initState() {
    super.initState();
    final app = context.read<AppState>();
    if (app.lockBiometric) {
      AppLock.biometricAvailable().then((ok) {
        if (!mounted) return;
        setState(() => _bioAvailable = ok);
        if (ok) _bio();
      });
    }
  }

  Future<void> _bio() async {
    final ok = await AppLock.authenticate(tr('Unlock Bijli Kab?'));
    if (ok && mounted) context.read<AppState>().unlock();
  }

  void _changed(String v) {
    setState(() {
      _pin = v;
      _error = false;
    });
    if (v.length == 4) {
      final app = context.read<AppState>();
      if (app.checkPin(v)) {
        app.unlock();
      } else {
        HapticFeedback.heavyImpact();
        setState(() {
          _error = true;
          _pin = '';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: BK.bg,
      child: Container(
        decoration: BoxDecoration(gradient: BK.backgroundGradient),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 20),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 360),
                child: Column(
                  children: [
                    ShaderMask(
                      shaderCallback: (r) => BK.accentGradient.createShader(r),
                      child: const Icon(
                        Icons.lock_rounded,
                        size: 64,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Bijli Kab?',
                      style: TextStyle(
                        color: BK.txt,
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _error
                          ? tr('Wrong PIN, try again')
                          : tr('Enter your PIN'),
                      style: TextStyle(color: _error ? BK.off : BK.muted),
                    ),
                    const SizedBox(height: 30),
                    PinPad(
                      value: _pin,
                      error: _error,
                      onChanged: _changed,
                      onBiometric: _bioAvailable ? _bio : null,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Choose a PIN (twice) to turn App Lock on.
class PinSetupScreen extends StatefulWidget {
  const PinSetupScreen({super.key});
  @override
  State<PinSetupScreen> createState() => _PinSetupScreenState();
}

class _PinSetupScreenState extends State<PinSetupScreen> {
  String _first = '';
  String _pin = '';
  bool _error = false;

  Future<void> _changed(String v) async {
    setState(() {
      _pin = v;
      _error = false;
    });
    if (v.length < 4) return;
    if (_first.isEmpty) {
      setState(() {
        _first = v;
        _pin = '';
      });
      return;
    }
    if (v == _first) {
      final app = context.read<AppState>();
      await app.setPin(v);
      final bio = await AppLock.biometricAvailable();
      if (bio) await app.setLockBiometric(true);
      if (mounted) {
        toast(context, tr('App Lock is on 🔒'));
        Navigator.pop(context);
      }
    } else {
      HapticFeedback.heavyImpact();
      setState(() {
        _error = true;
        _first = '';
        _pin = '';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return BScaffold(
      title: 'App Lock',
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 10),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Column(
              children: [
                const Text('🔒', style: TextStyle(fontSize: 54)),
                const SizedBox(height: 10),
                Text(
                  _error
                      ? tr('PINs did not match. Start again.')
                      : (_first.isEmpty
                            ? tr('Choose a 4-digit PIN')
                            : tr('Enter the same PIN again')),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _error ? BK.off : BK.txt,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  tr('You can turn this off any time in Settings.'),
                  textAlign: TextAlign.center,
                  style: TextStyle(color: BK.muted, fontSize: 13),
                ),
                const SizedBox(height: 26),
                PinPad(value: _pin, error: _error, onChanged: _changed),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
