import 'dart:convert';
import 'dart:typed_data';

import 'browser_download_stub.dart'
    if (dart.library.js_interop) 'browser_download_web.dart'
    as platform;

/// Browser download adapter that is a safe no-op on non-web targets.
abstract final class BrowserDownload {
  /// Normalizes a download filename for cross-platform safety (R63):
  /// strips path separators so a caller-supplied value (tenant/subject id)
  /// can never escape the download folder or inject a path, strips control
  /// characters, guards empty/`.`/`..` names with a neutral fallback, and
  /// caps over-long names while preserving a short extension.
  static String sanitizeFilename(String filename) {
    var name = filename.replaceAll(RegExp(r'[\\/]'), '-');
    name = name
        .replaceAll(RegExp(r'[\x00-\x1f\x7f]'), '')
        .trim()
        .replaceAll(RegExp(r'^\.+'), '');
    if (name.isEmpty) return 'export.json';
    if (name.length <= 120) return name;
    final dot = name.lastIndexOf('.');
    if (dot > 0 && name.length - dot <= 12) {
      return '${name.substring(0, 96)}${name.substring(dot)}';
    }
    return name.substring(0, 120);
  }

  static void bytes(
    List<int> bytes, {
    required String filename,
    required String contentType,
  }) {
    platform.downloadBytes(
      Uint8List.fromList(bytes),
      filename: sanitizeFilename(filename),
      contentType: contentType,
    );
  }

  static void text(
    String content, {
    required String filename,
    required String contentType,
  }) {
    bytes(utf8.encode(content), filename: filename, contentType: contentType);
  }

  /// Test-only hook: clears captured downloads (no-op on web).
  static void resetForTest() => platform.resetForTest();
}
