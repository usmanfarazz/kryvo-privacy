import '../models/models.dart';
import 'strings.dart';

String issueLabel(PowerIssue i) => switch (i) {
  PowerIssue.none => tr('No detail'),
  PowerIssue.lowVoltage => tr('Low voltage'),
  PowerIssue.tripping => tr('Tripping'),
  PowerIssue.transformer => tr('Transformer fault'),
  PowerIssue.scheduled => tr('Scheduled loadshedding'),
  PowerIssue.wireFault => tr('Wire / cable fault'),
};

String issueEmoji(PowerIssue i) => switch (i) {
  PowerIssue.none => '✔️',
  PowerIssue.lowVoltage => '🔅',
  PowerIssue.tripping => '🔁',
  PowerIssue.transformer => '💥',
  PowerIssue.scheduled => '🗓️',
  PowerIssue.wireFault => '🧵',
};
