import 'package:flutter/foundation.dart' show kIsWeb;

import '../app_settings.dart';
import 'product_api_origin.dart';

/// API origin for Agent Hub, separate from the Snaplink token issuer.
/// Browsers use the current page origin and `/api/v1/agent`; native shells may
/// use an explicitly configured HTTPS origin, falling back to the SSO origin.
abstract final class AgentHubApiOrigin {
  static String get baseUrl {
    if (kIsWeb) return ProductApiOrigin.baseUrl;
    return AppSettings.instance.agentHubBaseUrlOverride ??
        ProductApiOrigin.baseUrl;
  }
}
