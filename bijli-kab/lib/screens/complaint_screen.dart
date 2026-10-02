import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/format.dart';
import '../l10n/strings.dart';
import '../models/models.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// Well-known electricity complaint numbers. Users can type their own.
const kHelplines = [
  (
    '🇵🇰',
    'Pakistan (LESCO, IESCO, FESCO, MEPCO, GEPCO, PESCO, HESCO…)',
    '118',
  ),
  ('🇵🇰', 'K-Electric (Karachi)', '118'),
  ('🇮🇳', 'India (national power helpline)', '1912'),
];

/// Call / SMS the electricity company and keep complaint numbers.
class ComplaintScreen extends StatefulWidget {
  const ComplaintScreen({super.key});
  @override
  State<ComplaintScreen> createState() => _ComplaintScreenState();
}

class _ComplaintScreenState extends State<ComplaintScreen> {
  late final AppState app = context.read<AppState>();
  late final _number = TextEditingController(text: app.helpline);
  late final _ref = TextEditingController(text: app.consumerRef);

  @override
  void dispose() {
    _number.dispose();
    _ref.dispose();
    super.dispose();
  }

  void _save() => app.setHelpline(_number.text, _ref.text);

  String _message() {
    final a = app.active;
    final s = app.activeLive?.status;
    final since = s != null && s.state == PowerState.off && s.since != null
        ? trf('since {0}', [fmtTime(s.since!)])
        : '';
    return [
      tr('No electricity in our area.'),
      if (a != null) '${tr('Area')}: ${a.subtitle}',
      if (since.isNotEmpty) since,
      if (_ref.text.trim().isNotEmpty)
        '${tr('Reference no.')}: ${_ref.text.trim()}',
    ].join('\n');
  }

  Future<void> _open(Uri uri) async {
    _save();
    if (!await launchUrl(uri) && mounted) {
      toast(context, tr('Could not open the phone app.'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    return BScaffold(
      title: 'Complaint',
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 30),
        children: [
          GlassCard(
            glow: BK.off,
            child: Column(
              children: [
                const Text('📞', style: TextStyle(fontSize: 44)),
                const SizedBox(height: 6),
                Text(
                  tr('Light gone for too long? Complain in one tap.'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: BK.txt,
                    fontWeight: FontWeight.w900,
                    fontSize: 17,
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: BK.on,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () => _open(
                          Uri(scheme: 'tel', path: _number.text.trim()),
                        ),
                        icon: const Icon(Icons.call_rounded),
                        label: Text(trf('Call {0}', [_number.text.trim()])),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _open(
                          Uri.parse(
                            'sms:${_number.text.trim()}?body=${Uri.encodeComponent(_message())}',
                          ),
                        ),
                        icon: const Icon(Icons.sms_rounded),
                        label: Text(tr('SMS')),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SectionTitle('Helpline'),
          for (final (flag, name, num) in kHelplines)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: GlassCard(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                glow: _number.text.trim() == num && app.helpline == num
                    ? BK.accent
                    : null,
                onTap: () {
                  setState(() => _number.text = num);
                  _save();
                },
                child: Row(
                  children: [
                    Text(flag, style: const TextStyle(fontSize: 24)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        tr(name),
                        style: TextStyle(
                          color: BK.txt,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Text(
                      num,
                      style: TextStyle(
                        color: BK.accent,
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 6),
          TextField(
            controller: _number,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              labelText: tr('Helpline number (from your bill)'),
            ),
            onChanged: (_) {
              setState(() {});
              _save();
            },
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _ref,
            decoration: InputDecoration(
              labelText: tr('Reference / consumer number (optional)'),
            ),
            onChanged: (_) => _save(),
          ),
          SectionTitle(
            'My complaints',
            trailing: TextButton.icon(
              onPressed: () => _add(context),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: Text(tr('Add')),
            ),
          ),
          if (app.complaints.isEmpty)
            GlassCard(
              child: Text(
                tr(
                  'Got a complaint number from the helpline? Save it here so you can follow up.',
                ),
                style: TextStyle(color: BK.muted, height: 1.4),
              ),
            ),
          for (final c in app.complaints)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: GlassCard(
                padding: const EdgeInsets.fromLTRB(14, 10, 4, 10),
                child: Row(
                  children: [
                    const EmojiBox('🧾', size: 40),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            c.number.isEmpty
                                ? tr('Complaint')
                                : '# ${c.number}',
                            style: TextStyle(
                              color: BK.txt,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            '${fmtDay(c.at)} ${fmtTime(c.at)}${c.note.isEmpty ? '' : ' · ${c.note}'}',
                            style: TextStyle(color: BK.muted, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.delete_outline_rounded, color: BK.muted),
                      onPressed: () => app.removeComplaint(c),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 10),
          Text(
            tr(
              'Check the helpline number printed on your electricity bill — it can differ by company.',
            ),
            style: TextStyle(color: BK.muted, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Future<void> _add(BuildContext context) async {
    final number = TextEditingController();
    final note = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('Save complaint')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: number,
              autofocus: true,
              decoration: InputDecoration(labelText: tr('Complaint number')),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: note,
              decoration: InputDecoration(labelText: tr('Note (optional)')),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(tr('Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(tr('Save')),
          ),
        ],
      ),
    );
    if (ok == true) {
      await app.addComplaint(number.text.trim(), note.text.trim());
    }
    number.dispose();
    note.dispose();
  }
}
