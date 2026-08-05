import 'dart:typed_data';

/// Captured downloads on the VM stub platform, used by tests to assert the
/// bytes, filename and content type without a browser.
final List<Map<String, Object?>> capturedDownloads = [];

void downloadBytes(
  Uint8List bytes, {
  required String filename,
  required String contentType,
}) {
  capturedDownloads.add({
    'bytes': bytes,
    'filename': filename,
    'contentType': contentType,
  });
}

/// Test-only hook: clears captured downloads between tests.
void resetForTest() {
  capturedDownloads.clear();
}
