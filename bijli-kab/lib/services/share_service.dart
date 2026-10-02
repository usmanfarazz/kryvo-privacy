import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../l10n/strings.dart';

const kPlayStoreUrl =
    'https://play.google.com/store/apps/details?id=com.farazlabs.bijli_kab';

class ShareService {
  /// Renders the widget under [key] (a RepaintBoundary) and shares it.
  static Future<bool> shareWidget(GlobalKey key, String text) async {
    try {
      final boundary =
          key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return false;
      final image = await boundary.toImage(pixelRatio: 3);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      if (bytes == null) return false;
      final dir = await getTemporaryDirectory();
      final file = File(
        '${dir.path}/bijli_kab_${DateTime.now().millisecondsSinceEpoch}.png',
      );
      await file.writeAsBytes(bytes.buffer.asUint8List());
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: 'image/png')],
          text: '$text\n$kPlayStoreUrl',
        ),
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<void> shareApp() => SharePlus.instance.share(
    ShareParams(
      text:
          '${tr('Know when the light will go — before it goes! ⚡ Try Bijli Kab?')}\n$kPlayStoreUrl',
    ),
  );

  static Future<void> shareText(String text) =>
      SharePlus.instance.share(ShareParams(text: '$text\n$kPlayStoreUrl'));
}
