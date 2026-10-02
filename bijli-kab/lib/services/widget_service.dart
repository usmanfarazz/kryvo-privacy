import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';

import '../l10n/format.dart';
import '../l10n/strings.dart';
import '../models/models.dart';

/// Pushes the primary area's status to the Android home-screen widget
/// (android/app/src/main/kotlin/.../BijliWidgetProvider.kt).
class WidgetService {
  static Future<void> update({
    required String areaName,
    required AreaStatus status,
    PredictedOutage? next,
    DateTime? restoreEta,
  }) async {
    try {
      final state = status.state.name;
      final headline = switch (status.state) {
        PowerState.on => tr('Light is ON'),
        PowerState.off => tr('Light is OFF'),
        PowerState.unknown => tr('No recent reports'),
      };
      final since = status.since == null
          ? ''
          : trf('for {0}', [
              fmtDuration(DateTime.now().difference(status.since!)),
            ]);
      final hint = status.state == PowerState.off
          ? (restoreEta == null ? '' : trf('Back ~{0}', [fmtTime(restoreEta)]))
          : (next == null
                ? tr('No cut expected soon')
                : trf('Next cut ~{0}', [fmtTime(next.start)]));
      await HomeWidget.saveWidgetData<String>('bk_area', areaName);
      await HomeWidget.saveWidgetData<String>('bk_state', state);
      await HomeWidget.saveWidgetData<String>('bk_headline', headline);
      await HomeWidget.saveWidgetData<String>('bk_since', since);
      await HomeWidget.saveWidgetData<String>('bk_hint', hint);
      await HomeWidget.saveWidgetData<String>(
        'bk_updated',
        trf('Updated {0}', [fmtTime(DateTime.now())]),
      );
      await HomeWidget.updateWidget(androidName: 'BijliWidgetProvider');
    } catch (e) {
      debugPrint('widget update skipped: $e');
    }
  }
}
