import 'package:flutter/foundation.dart' show kIsWeb;

import '../app_settings.dart';

/// The single trusted origin used by every Snaplink API client.
///
/// Browser builds stay on the page origin. Native builds use the validated
/// operator override, falling back to the hosted Snaplink service.
abstract final class ProductApiOrigin {
  static const nativeDefaultBaseUrl = 'https://sso.ywbsd.site';

  static String get baseUrl {
    if (kIsWeb) {
      final page = Uri.base;
      if (page.host.isEmpty) {
        throw StateError('The web application has no page origin.');
      }
      return Uri(
        scheme: page.scheme,
        host: page.host,
        port: page.hasPort ? page.port : null,
      ).toString();
    }
    return AppSettings.instance.ssoBaseUrlOverride ?? nativeDefaultBaseUrl;
  }

  static Uri get baseUri =>
      Uri.parse('${baseUrl.replaceAll(RegExp(r'/+$'), '')}/');
}
