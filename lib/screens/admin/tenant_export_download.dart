import 'package:sso_admin/services/browser_download.dart';

import 'snaplink_admin_types.dart';

/// Starts a browser download without rendering the sensitive payload.
void downloadAdminAttachment(
  SnaplinkAdminDownload export, {
  required String fallbackFilename,
}) {
  BrowserDownload.bytes(
    export.bytes,
    filename: export.filename ?? fallbackFilename,
    contentType: export.contentType,
  );
}

/// Starts a browser download for a tenant export without rendering its data.
void downloadTenantExport(SnaplinkAdminDownload export, String tenantId) {
  downloadAdminAttachment(
    export,
    fallbackFilename: 'snaplink-$tenantId-export.json',
  );
}
