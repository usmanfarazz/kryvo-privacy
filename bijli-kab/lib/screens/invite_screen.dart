import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../l10n/strings.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// Share your area code with friends and family; follow theirs.
class InviteScreen extends StatefulWidget {
  const InviteScreen({super.key});
  @override
  State<InviteScreen> createState() => _InviteScreenState();
}

class _InviteScreenState extends State<InviteScreen> {
  final _code = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final code = app.inviteCode;
    return BScaffold(
      title: 'Invite friends',
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 30),
        children: [
          GlassCard(
            glow: BK.accent,
            gradient: LinearGradient(
              colors: [
                BK.accent.withValues(alpha: 0.25),
                BK.accent2.withValues(alpha: 0.1),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            child: Column(
              children: [
                const Text('👨‍👩‍👧‍👦', style: TextStyle(fontSize: 48)),
                const SizedBox(height: 8),
                Text(
                  tr('More neighbours = more accurate light status'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: BK.txt,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  tr(
                    'Invite your street and family. They can follow your area with your code.',
                  ),
                  textAlign: TextAlign.center,
                  style: TextStyle(color: BK.muted, fontSize: 13),
                ),
                const SizedBox(height: 16),
                Text(
                  tr('Your area code'),
                  style: TextStyle(color: BK.muted, fontSize: 12.5),
                ),
                const SizedBox(height: 4),
                GestureDetector(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: code));
                    toast(context, tr('Code copied'));
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 22,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: BK.panel2,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: BK.accent),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          code.toUpperCase(),
                          style: TextStyle(
                            color: BK.txt,
                            fontSize: 30,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 4,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Icon(Icons.copy_rounded, color: BK.muted, size: 20),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                GradientButton(
                  label: tr('Invite on WhatsApp & more'),
                  icon: Icons.share_rounded,
                  onPressed: app.shareInvite,
                ),
                const SizedBox(height: 8),
                Text(
                  trf('Invites sent: {0}', [app.invites]),
                  style: TextStyle(color: BK.muted, fontSize: 12.5),
                ),
              ],
            ),
          ),
          const SectionTitle('Got a code from a friend?'),
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  app.usedFriendCode
                      ? tr('Follow your friend\'s or family\'s area.')
                      : tr(
                          'Follow their area — and get +20 welcome points the first time!',
                        ),
                  style: TextStyle(color: BK.muted, fontSize: 13),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _code,
                        textCapitalization: TextCapitalization.characters,
                        maxLength: 6,
                        decoration: InputDecoration(
                          hintText: tr('6-letter code'),
                          counterText: '',
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    FilledButton(
                      onPressed: _busy
                          ? null
                          : () async {
                              setState(() => _busy = true);
                              final r = await app.addFriendCode(_code.text);
                              if (!mounted) return;
                              setState(() => _busy = false);
                              toast(this.context, switch (r) {
                                FriendCodeResult.added => tr(
                                  'Area added to your list 🤝',
                                ),
                                FriendCodeResult.alreadyFollowing => tr(
                                  'You already follow this area.',
                                ),
                                FriendCodeResult.invalid => tr(
                                  'That code doesn\'t look right. It has 6 letters/numbers.',
                                ),
                              });
                              if (r == FriendCodeResult.added) _code.clear();
                            },
                      child: Text(tr('Add')),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            tr('The code only shows the ~1 km area, never your exact home.'),
            style: TextStyle(color: BK.muted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
