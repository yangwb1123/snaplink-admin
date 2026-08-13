import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;

import '../../services/browser_download.dart';

/// Filename used for the self-service privacy data export attachment.
const String portalExportFilename = 'snaplink-data-export.json';

/// Delivers a self-service privacy export as a browser attachment.
///
/// Returns false on shells without a browser download surface (VM/native);
/// callers must then surface the honest "available in the web console"
/// message instead of pretending a file was saved.
bool downloadPortalExport(http.Response response) {
  if (!kIsWeb) return false;
  BrowserDownload.bytes(
    response.bodyBytes,
    filename: portalExportFilename,
    contentType: response.headers['content-type'] ?? 'application/json',
  );
  return true;
}
