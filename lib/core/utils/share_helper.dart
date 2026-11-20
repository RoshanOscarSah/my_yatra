// Adapted from Hariyo Naksha's share_helper.dart (Roshan Sah), updated for
// the share_plus 13 API.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

/// Centralizes share sheet calls with a valid iOS/iPadOS popover anchor.
class ShareHelper {
  ShareHelper._();

  static Rect _origin(BuildContext context) {
    final ro = context.findRenderObject();
    if (ro is RenderBox && ro.hasSize && ro.size.width > 0 && ro.size.height > 0) {
      return ro.localToGlobal(Offset.zero) & ro.size;
    }
    final size = MediaQuery.sizeOf(context);
    return Rect.fromCenter(center: Offset(size.width / 2, size.height / 2), width: 2, height: 2);
  }

  static Rect? _originForPlatform(BuildContext context) {
    if (kIsWeb) return null;
    return switch (defaultTargetPlatform) {
      TargetPlatform.iOS || TargetPlatform.macOS => _origin(context),
      _ => null,
    };
  }

  static Future<void> shareText(BuildContext context, String text, {String? subject}) =>
      SharePlus.instance.share(ShareParams(
        text: text,
        subject: subject,
        sharePositionOrigin: _originForPlatform(context),
      ));

  static Future<void> shareFiles(BuildContext context, List<XFile> files,
          {String? subject, String? text}) =>
      SharePlus.instance.share(ShareParams(
        files: files,
        text: text,
        subject: subject,
        sharePositionOrigin: _originForPlatform(context),
      ));
}
