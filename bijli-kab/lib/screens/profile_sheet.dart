import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/strings.dart';
import '../state/app_state.dart';
import '../theme.dart';

const kAvatars = [
  '😎',
  '🦁',
  '🐯',
  '🦊',
  '🐼',
  '🦅',
  '🚀',
  '⚡',
  '🌙',
  '🌸',
  '🔥',
  '🎯',
  '👑',
  '🧠',
  '🦸',
  '🧕',
  '👨‍🔧',
  '👩‍💻',
  '🏏',
  '🌟',
];

Future<void> showProfileSheet(BuildContext context) => showModalBottomSheet(
  context: context,
  isScrollControlled: true,
  builder: (_) => const ProfileEditor(),
);

/// Nickname + avatar, shown on the leaderboard.
class ProfileEditor extends StatefulWidget {
  final VoidCallback? onSaved;
  final bool inline;
  const ProfileEditor({super.key, this.onSaved, this.inline = false});
  @override
  State<ProfileEditor> createState() => _ProfileEditorState();
}

class _ProfileEditorState extends State<ProfileEditor> {
  late final _name = TextEditingController(text: context.read<AppState>().name);
  late String _avatar = context.read<AppState>().avatar;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 88,
          height: 88,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: BK.accentGradient,
            boxShadow: [
              BoxShadow(
                color: BK.accent.withValues(alpha: 0.4),
                blurRadius: 24,
              ),
            ],
          ),
          child: Text(_avatar, style: const TextStyle(fontSize: 46)),
        ),
        const SizedBox(height: 18),
        TextField(
          controller: _name,
          maxLength: 20,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            labelText: tr('Nickname (shown on leaderboard)'),
            counterText: '',
          ),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: [
            for (final a in kAvatars)
              GestureDetector(
                onTap: () => setState(() => _avatar = a),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 48,
                  height: 48,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _avatar == a
                        ? BK.accent.withValues(alpha: 0.22)
                        : BK.panel2,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: _avatar == a ? BK.accent : BK.line,
                    ),
                  ),
                  child: Text(a, style: const TextStyle(fontSize: 24)),
                ),
              ),
          ],
        ),
        const SizedBox(height: 18),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: () async {
              await context.read<AppState>().saveProfile(_name.text, _avatar);
              if (widget.onSaved != null) {
                widget.onSaved!();
              } else if (context.mounted) {
                Navigator.pop(context);
              }
            },
            child: Text(widget.inline ? tr('Continue') : tr('Save')),
          ),
        ),
      ],
    );
    if (widget.inline) return content;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          24,
          20,
          16 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SingleChildScrollView(child: content),
      ),
    );
  }
}
