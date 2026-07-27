import 'dart:convert';
import 'dart:typed_data';

import 'browser_download_stub.dart'
    if (dart.library.js_interop) 'browser_download_web.dart'
    as platform;

/// Browser download adapter that is a safe no-op on non-web targets.
abstract final class BrowserDownload {
  static void bytes(
    List<int> bytes, {
    required String filename,
    required String contentType,
  }) {
    platform.downloadBytes(
      Uint8List.fromList(bytes),
      filename: filename,
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
}
