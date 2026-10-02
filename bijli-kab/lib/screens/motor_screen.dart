import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/format.dart';
import '../l10n/strings.dart';
import '../models/models.dart';
import '../services/notification_service.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// Water-pump timer: reminds you to switch the motor off when the tank is
/// full, and tells you if the light went while it was running.
class MotorScreen extends StatefulWidget {
  const MotorScreen({super.key});
  @override
  State<MotorScreen> createState() => _MotorScreenState();
}

class _MotorScreenState extends State<MotorScreen> {
  late int _minutes = context.read<AppState>().tankMinutes;
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final ends = app.motorEndsAt;
    final running = ends != null && ends.isAfter(DateTime.now());
    final left = running ? ends.difference(DateTime.now()) : Duration.zero;
    final total = Duration(minutes: app.tankMinutes);
    final progress = running && total.inSeconds > 0
        ? 1 - left.inSeconds / total.inSeconds
        : 0.0;
    final lightOn = app.live[app.primary?.id]?.status.state == PowerState.on;
    final mm = left.inMinutes.toString().padLeft(2, '0');
    final ss = (left.inSeconds % 60).toString().padLeft(2, '0');

    return BScaffold(
      title: 'Water pump timer',
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 30),
        children: [
          GlassCard(
            glow: running ? const Color(0xFF0EA5E9) : null,
            child: Column(
              children: [
                SizedBox(
                  width: 210,
                  height: 210,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox.expand(
                        child: CircularProgressIndicator(
                          value: progress,
                          strokeWidth: 14,
                          backgroundColor: BK.panel2,
                          valueColor: const AlwaysStoppedAnimation(
                            Color(0xFF0EA5E9),
                          ),
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('🚰', style: TextStyle(fontSize: 44)),
                          Text(
                            running
                                ? '$mm:$ss'
                                : fmtDuration(Duration(minutes: _minutes)),
                            style: TextStyle(
                              color: BK.txt,
                              fontSize: 34,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          Text(
                            running
                                ? tr('until the tank is full')
                                : tr('to fill the tank'),
                            style: TextStyle(color: BK.muted, fontSize: 12.5),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                if (!running) ...[
                  Text(
                    trf('Tank fills in {0} minutes', [_minutes]),
                    style: TextStyle(
                      color: BK.txt,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Slider(
                    value: _minutes.toDouble(),
                    min: 5,
                    max: 120,
                    divisions: 23,
                    onChanged: (v) => setState(() => _minutes = v.round()),
                  ),
                  GradientButton(
                    label: tr('Start pump timer'),
                    icon: Icons.play_arrow_rounded,
                    onPressed: () async {
                      await NotificationService.requestPermission();
                      await app.startMotor(_minutes);
                    },
                  ),
                  if (!lightOn) ...[
                    const SizedBox(height: 10),
                    Text(
                      tr(
                        'The light seems to be off in your main area — the pump may not run.',
                      ),
                      textAlign: TextAlign.center,
                      style: TextStyle(color: BK.warn, fontSize: 12.5),
                    ),
                  ],
                ] else
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: app.stopMotor,
                      icon: const Icon(Icons.stop_rounded),
                      label: Text(tr('Stop timer')),
                    ),
                  ),
              ],
            ),
          ),
          const SectionTitle('Reminders'),
          GlassCard(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: BTile(
              icon: Icons.notifications_active_rounded,
              title: 'Remind me when the light comes back',
              subtitle: tr('So you can fill the tank while there is power'),
              onTap: () => app.setExtras(motor: !app.motorReminder),
              trailing: Switch(
                value: app.motorReminder,
                onChanged: (v) => app.setExtras(motor: v),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            tr(
              'If the light goes while the timer runs, you get a notification and the timer stops.',
            ),
            style: TextStyle(color: BK.muted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
