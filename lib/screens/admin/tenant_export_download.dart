import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'snaplink_admin_types.dart';

/// Starts a browser download without rendering the sensitive payload.
void downloadAdminAttachment(
  SnaplinkAdminDownload export, {
  required String fallbackFilename,
}) {
  final blob = web.Blob(
    <JSUint8Array>[export.bytes.toJS].toJS,
    web.BlobPropertyBag(type: export.contentType),
  );
  final url = web.URL.createObjectURL(blob);
  final anchor = web.HTMLAnchorElement()
    ..href = url
    ..download = export.filename ?? fallbackFilename;
  web.document.body?.append(anchor);
  anchor.click();
  anchor.remove();
  web.URL.revokeObjectURL(url);
}

/// Starts a browser download for a tenant export without rendering its data.
void downloadTenantExport(SnaplinkAdminDownload export, String tenantId) {
  downloadAdminAttachment(
    export,
    fallbackFilename: 'snaplink-$tenantId-export.json',
  );
}
