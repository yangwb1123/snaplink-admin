import 'product_api_origin.dart';

/// API origin for Forge Conversations.
///
/// Web uses the page origin by default. Any build may set
/// FORGE_CONVERSATIONS_API_ORIGIN at build time; otherwise native builds use
/// the configured Snaplink origin, matching the Console's same-origin model.
abstract final class ForgeConversationsApiOrigin {
  static const configuredOverride = String.fromEnvironment(
    'FORGE_CONVERSATIONS_API_ORIGIN',
  );

  static String get baseUrl {
    final value = configuredOverride.trim();
    return value.isEmpty ? ProductApiOrigin.baseUrl : normalizeOrigin(value);
  }

  /// Accepts only an HTTPS origin, except HTTP loopback used by local builds.
  static String normalizeOrigin(String value) {
    final uri = Uri.tryParse(value.trim());
    final host = uri?.host.toLowerCase() ?? '';
    final parts = host.split('.');
    final loopback =
        host == 'localhost' ||
        host == '::1' ||
        (parts.length == 4 &&
            parts.first == '127' &&
            parts.every((part) {
              final octet = int.tryParse(part);
              return octet != null && octet >= 0 && octet <= 255;
            }));
    if (uri == null ||
        !uri.hasAuthority ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        (uri.scheme != 'https' && !(uri.scheme == 'http' && loopback)) ||
        !(uri.path.isEmpty || uri.path == '/') ||
        uri.hasQuery ||
        uri.hasFragment) {
      throw const FormatException('invalid_forge_conversations_api_origin');
    }
    return Uri(
      scheme: uri.scheme,
      host: uri.host,
      port: uri.hasPort ? uri.port : null,
    ).toString();
  }
}
