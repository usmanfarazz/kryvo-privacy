import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/strings.dart';
import '../services/notification_service.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'about_screen.dart';
import 'areas_screen.dart';
import 'lock_screen.dart';
import '../models/models.dart';
import 'profile_sheet.dart';
import 'theme_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    void open(Widget w) =>
        Navigator.push(context, MaterialPageRoute(builder: (_) => w));
    final lang = kLanguages.firstWhere((l) => l.code == app.lang);

    return BScaffold(
      title: 'Settings',
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 30),
        children: [
          const SectionTitle('Alerts'),
          GlassCard(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Column(
              children: [
                _Switch(
                  icon: Icons.notifications_active_rounded,
                  title: 'Warn me before a cut',
                  subtitle: tr('Based on the forecast for your main area'),
                  value: app.predictAlerts,
                  onChanged: (v) async {
                    if (v) await NotificationService.requestPermission();
                    app.setAlerts(predict: v);
                  },
                ),
                if (app.predictAlerts)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(54, 0, 0, 10),
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final m in [5, 10, 15, 30, 60])
                          ChoiceChip(
                            label: Text(trf('{0} min before', [m])),
                            selected: app.leadMinutes == m,
                            onSelected: (_) => app.setAlerts(lead: m),
                          ),
                      ],
                    ),
                  ),
                _Switch(
                  icon: Icons.campaign_rounded,
                  title: 'Light gone / back alerts',
                  subtitle: tr('When neighbours report a change'),
                  value: app.liveAlerts,
                  onChanged: (v) async {
                    if (v) await NotificationService.requestPermission();
                    app.setAlerts(liveChanges: v);
                  },
                ),
                _Switch(
                  icon: Icons.checklist_rounded,
                  title: 'Checklist reminder',
                  subtitle: tr('30 min before the next cut'),
                  value: app.checklistReminder,
                  onChanged: (v) => app.setAlerts(checklistReminder: v),
                ),
                _Switch(
                  icon: Icons.bedtime_rounded,
                  title: 'Quiet hours',
                  subtitle: tr('No alerts from 11 pm to 7 am'),
                  value: app.quietHours,
                  onChanged: (v) => app.setAlerts(quiet: v),
                ),
                BTile(
                  icon: Icons.music_note_rounded,
                  title: 'Alert sound',
                  subtitle: _soundName(app.alertSound),
                  onTap: () => _pickSound(context),
                ),
              ],
            ),
          ),
          const SectionTitle('Extras'),
          GlassCard(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Column(
              children: [
                _Switch(
                  icon: Icons.celebration_rounded,
                  title: 'Celebrate when light comes back',
                  subtitle: tr('Confetti and a sound in the app'),
                  value: app.celebrateOn,
                  onChanged: (v) => app.setExtras(celebrate: v),
                ),
                _Switch(
                  icon: Icons.push_pin_rounded,
                  title: 'Status in notification bar',
                  subtitle: tr('Always see light ON/OFF and the next cut'),
                  value: app.statusBar,
                  onChanged: (v) async {
                    if (v) await NotificationService.requestPermission();
                    app.setExtras(statusLine: v);
                  },
                ),
                _Switch(
                  icon: Icons.battery_charging_full_rounded,
                  title: 'UPS reminders',
                  subtitle: tr(
                    'Backup time when the light goes, "fully charged" later',
                  ),
                  value: app.upsReminder,
                  onChanged: (v) => app.setExtras(ups: v),
                ),
                if (app.upsReminder)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(54, 0, 0, 10),
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final h in [4, 6, 8, 10])
                          ChoiceChip(
                            label: Text(trf('Full in {0}h', [h])),
                            selected: app.upsChargeHours == h,
                            onSelected: (_) => app.setExtras(upsHours: h),
                          ),
                      ],
                    ),
                  ),
                _Switch(
                  icon: Icons.water_drop_rounded,
                  title: 'Water pump reminder',
                  subtitle: tr('When the light comes back'),
                  value: app.motorReminder,
                  onChanged: (v) => app.setExtras(motor: v),
                ),
              ],
            ),
          ),
          const SectionTitle('Security'),
          GlassCard(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Column(
              children: [
                _Switch(
                  icon: Icons.lock_rounded,
                  title: 'App Lock',
                  subtitle: app.lockEnabled
                      ? tr('PIN needed to open the app')
                      : tr('Off — the app opens without a password'),
                  value: app.lockEnabled,
                  onChanged: (v) {
                    if (v) {
                      open(const PinSetupScreen());
                    } else {
                      app.disableLock();
                    }
                  },
                ),
                if (app.lockEnabled) ...[
                  _Switch(
                    icon: Icons.fingerprint_rounded,
                    title: 'Fingerprint / face unlock',
                    subtitle: tr(
                      'Use the phone\'s fingerprint instead of the PIN',
                    ),
                    value: app.lockBiometric,
                    onChanged: app.setLockBiometric,
                  ),
                  BTile(
                    icon: Icons.password_rounded,
                    title: 'Change PIN',
                    onTap: () => open(const PinSetupScreen()),
                  ),
                ],
              ],
            ),
          ),
          const SectionTitle('Look & feel'),
          GlassCard(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Column(
              children: [
                BTile(
                  icon: Icons.palette_rounded,
                  title: 'Theme',
                  subtitle: '${BK.current.emoji} ${tr(BK.current.name)}',
                  onTap: () => open(const ThemeScreen()),
                ),
                BTile(
                  icon: Icons.translate_rounded,
                  title: 'Language',
                  subtitle: lang.name,
                  onTap: () => _pickLanguage(context),
                ),
                _Switch(
                  icon: Icons.vibration_rounded,
                  title: 'Vibration',
                  subtitle: tr('Haptic feedback on taps'),
                  value: app.haptics,
                  onChanged: app.setHaptics,
                ),
              ],
            ),
          ),
          const SectionTitle('You'),
          GlassCard(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Column(
              children: [
                BTile(
                  icon: Icons.person_rounded,
                  title: 'Profile',
                  subtitle:
                      '${app.avatar} ${app.name.isEmpty ? tr('Set your name') : app.name}',
                  onTap: () => showProfileSheet(context),
                ),
                BTile(
                  icon: Icons.place_rounded,
                  title: 'My areas',
                  subtitle: trf('{0} followed', [app.areas.length]),
                  onTap: () => open(const AreasScreen()),
                ),
              ],
            ),
          ),
          const SectionTitle('Data'),
          GlassCard(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Column(
              children: [
                BTile(
                  icon: app.repo.isLive
                      ? Icons.cloud_done_rounded
                      : Icons.science_rounded,
                  color: app.repo.isLive ? BK.on : BK.warn,
                  title: app.repo.isLive ? 'Connected' : 'Demo mode',
                  subtitle: app.repo.isLive
                      ? tr('Reports are shared live with your neighbours')
                      : tr(
                          'Simulated neighbours. The developer must connect Firebase to go live.',
                        ),
                ),
                BTile(
                  icon: Icons.delete_forever_rounded,
                  color: BK.off,
                  title: 'Reset app',
                  subtitle: tr('Delete everything stored on this phone'),
                  onTap: () => _reset(context),
                ),
              ],
            ),
          ),
          const SectionTitle('About'),
          GlassCard(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: BTile(
              icon: Icons.info_rounded,
              title: 'About, privacy & feedback',
              subtitle: 'Bijli Kab? v1.0.0',
              onTap: () => open(const AboutScreen()),
            ),
          ),
        ],
      ),
    );
  }

  static String _soundName(String s) => switch (s) {
    'chime' => '🎶 ${tr('Chime')}',
    'bell' => '🔔 ${tr('Bell')}',
    'siren' => '🚨 ${tr('Siren')}',
    'horn' => '📯 ${tr('Horn')}',
    _ => '📱 ${tr('Phone default')}',
  };

  Future<void> _pickSound(BuildContext context) => showModalBottomSheet(
    context: context,
    builder: (ctx) {
      final app = ctx.watch<AppState>();
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 16),
            Text(
              tr('Alert sound'),
              style: TextStyle(
                color: BK.txt,
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            for (final s in ['default', ...kAlertSounds])
              ListTile(
                title: Text(
                  _soundName(s),
                  style: TextStyle(color: BK.txt, fontWeight: FontWeight.w800),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (app.alertSound == s)
                      Icon(Icons.check_circle_rounded, color: BK.accent),
                    IconButton(
                      icon: Icon(Icons.play_circle_rounded, color: BK.muted),
                      onPressed: () async {
                        await app.setExtras(sound: s);
                        await NotificationService.requestPermission();
                        await NotificationService.test();
                      },
                    ),
                  ],
                ),
                onTap: () => app.setExtras(sound: s),
              ),
            const SizedBox(height: 8),
          ],
        ),
      );
    },
  );

  Future<void> _pickLanguage(BuildContext context) => showModalBottomSheet(
    context: context,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 16),
          Text(
            tr('Language'),
            style: TextStyle(
              color: BK.txt,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          for (final l in kLanguages)
            ListTile(
              title: Text(
                l.name,
                style: TextStyle(color: BK.txt, fontWeight: FontWeight.w800),
              ),
              subtitle: Text(l.hint, style: TextStyle(color: BK.muted)),
              trailing: context.read<AppState>().lang == l.code
                  ? Icon(Icons.check_circle_rounded, color: BK.accent)
                  : null,
              onTap: () {
                context.read<AppState>().setLang(l.code);
                Navigator.pop(ctx);
              },
            ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );

  Future<void> _reset(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('Reset app?')),
        content: Text(
          tr(
            'Your areas, points, settings and checklist on this phone will be deleted. Reports you already sent stay with the community.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(tr('Cancel')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: BK.off,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(tr('Reset')),
          ),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      Navigator.of(context).popUntil((r) => r.isFirst);
      await context.read<AppState>().resetAll();
    }
  }
}

class _Switch extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _Switch({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });
  @override
  Widget build(BuildContext context) => BTile(
    icon: icon,
    title: title,
    subtitle: subtitle,
    onTap: () => onChanged(!value),
    trailing: Switch(value: value, onChanged: onChanged),
  );
}
