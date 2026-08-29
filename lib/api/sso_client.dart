import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:sso_admin/api/admin_paths.dart';
import 'package:sso_admin/session.dart';
import 'package:sso_admin/services/admin_oauth_resources.dart';
import 'package:sso_admin/services/product_api_origin.dart';

part 'sso_client_session.dart';
part 'sso_client_resources.dart';
part 'sso_client_transport.dart';

/// Thrown on any non-2xx response from the SSO server; carries the parsed
/// error body when the response was JSON.
class SSOError implements Exception {
  final int status;
  final String? error;
  final String? errorDescription;

  SSOError(this.status, this.error, this.errorDescription);

  @override
  String toString() {
    if (errorDescription != null) return errorDescription!;
    if (error != null) return error!;
    // Same 401/403 convention as the admin API error: a bare 403 is a
    // permission denial on a still-valid session, never a session expiry.
    if (status == 403) {
      return 'This session is not authorized for this operation (403).';
    }
    return 'SSO request failed with status $status';
  }
}

/// A cursor page returned by Snaplink's administrative list endpoints.
///
/// The cursor is intentionally opaque; callers must send it back unchanged
/// with the same filter and ordering that produced the page.
class SSOAdminListPage {
  final List<Map<String, dynamic>> items;
  final String? nextPageToken;
  final int? totalSize;

  const SSOAdminListPage({
    required this.items,
    required this.nextPageToken,
    required this.totalSize,
  });
}

/// Minimal admin-API client for the sso_admin Flutter app: direct
/// password-grant login (mirrors the TypeScript SDK's login()) plus the
/// small slice of the admin REST surface this MVP covers (clients, users,
/// tenants + suspend/activate).
class SSOAdminClient {
  final String baseUrl;
  final http.Client _http;
  final Duration requestTimeout;
  final void Function()? onUnauthorized;
  String? _token;

  SSOAdminClient(
    String baseUrl, {
    http.Client? httpClient,
    this.requestTimeout = const Duration(seconds: 30),
    this.onUnauthorized,
  }) : baseUrl = _stripTrailingSlash(baseUrl),
       _http = httpClient ?? http.Client();

  /// Uses the current page origin on web and the configured service origin on
  /// native platforms.
  factory SSOAdminClient.sameOrigin() =>
      SSOAdminClient(ProductApiOrigin.baseUrl);

  /// Wraps an access_token already obtained elsewhere (the unified /login
  /// screen) as a logged-in client, without a second network round trip.
  factory SSOAdminClient.withToken(
    String accessToken, {
    String? baseUrl,
    void Function()? onUnauthorized,
  }) {
    final client = SSOAdminClient(
      baseUrl ?? ProductApiOrigin.baseUrl,
      onUnauthorized: onUnauthorized,
    );
    client._token = accessToken;
    return client;
  }

  static const nativeDefaultBaseUrl = ProductApiOrigin.nativeDefaultBaseUrl;

  /// OAuth2 client identifier used by this first-party console for direct
  /// login and admin access. Single source of truth: the hosted-login
  /// wiring and every test reference this constant instead of a fresh
  /// literal (single-source rule).
  static const String firstPartyClientId = 'sso-admin-console';

  static String _stripTrailingSlash(String s) =>
      s.replaceAll(RegExp(r'/+$'), '');

  bool get isLoggedIn => _token != null;
}
