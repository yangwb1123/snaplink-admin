import 'dart:js_interop';

import 'package:http/http.dart' as http;
import 'package:web/web.dart' as web;

/// Delivers a self-service privacy export as a browser attachment.
void downloadPortalExport(http.Response response) {
  final blob = web.Blob(
    <JSUint8Array>[response.bodyBytes.toJS].toJS,
    web.BlobPropertyBag(
      type: response.headers['content-type'] ?? 'application/json',
    ),
  );
  final url = web.URL.createObjectURL(blob);
  final anchor = web.HTMLAnchorElement()
    ..href = url
    ..download = 'snaplink-data-export.json';
  web.document.body?.append(anchor);
  anchor.click();
  anchor.remove();
  web.URL.revokeObjectURL(url);
}
