import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;

import '../../services/browser_download.dart';

/// Delivers a self-service privacy export as a browser attachment.
bool downloadPortalExport(http.Response response) {
  if (!kIsWeb) return false;
  BrowserDownload.bytes(
    response.bodyBytes,
    filename: 'snaplink-data-export.json',
    contentType: response.headers['content-type'] ?? 'application/json',
  );
  return true;
}
