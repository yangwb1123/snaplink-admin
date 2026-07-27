import 'package:sso_admin/api/snaplink_admin_types.dart';

/// Build-time catalog generated from Snaplink's `docs/openapi.yaml`.
///
/// Snaplink's runtime endpoint inventory is still used for feature awareness,
/// but current server versions do not report every gRPC-gateway operation in
/// that inventory. Keeping the documented routes here prevents those valid
/// operations from disappearing from the console. Regenerate this list from
/// that OpenAPI contract whenever the backend API changes.
class SnaplinkAdminOperationCatalog {
  static final endpoints = routes
      .trim()
      .split('\n')
      .map((line) {
        final space = line.indexOf(' ');
        return SnaplinkAdminEndpoint(
          method: line.substring(0, space),
          path: line.substring(space + 1),
          feature: 'documented',
        );
      })
      .toList(growable: false);

  static List<SnaplinkAdminEndpoint> mergedWith(
    List<SnaplinkAdminEndpoint> liveEndpoints,
  ) {
    final liveByRoute = {
      for (final endpoint in liveEndpoints) _key(endpoint): endpoint,
    };
    final merged = <SnaplinkAdminEndpoint>[];
    for (final documented in endpoints) {
      merged.add(liveByRoute.remove(_key(documented)) ?? documented);
    }
    merged.addAll(liveByRoute.values);
    return merged;
  }

  /// Whether a documented route family is available even when an older
  /// runtime inventory omits its gRPC-gateway registration.
  static bool hasDocumentedPathPrefix(String prefix) => endpoints.any(
    (endpoint) => _normalizedPath(endpoint.path).startsWith(prefix),
  );

  static String _key(SnaplinkAdminEndpoint endpoint) =>
      '${endpoint.method} ${_normalizedPath(endpoint.path)}';

  static String _normalizedPath(String path) => path.replaceAllMapped(
    RegExp(r'\{([A-Za-z_][A-Za-z0-9_]*)\}'),
    (match) => ':${match.group(1)}',
  );
}

/// Temporary compatibility manifest for mounted routes that Snaplink has not
/// yet included in OpenAPI or its runtime inventory.
///
/// Presence here means "known to exist in some server builds", not
/// "advertised by this replica". Screens must probe these routes safely and
/// degrade cleanly when a deployment returns 404 or 501.
class SnaplinkAdminSupplementalCatalog {
  static final endpoints = supplementalRoutes
      .trim()
      .split('\n')
      .map((line) {
        final space = line.indexOf(' ');
        return SnaplinkAdminEndpoint(
          method: line.substring(0, space),
          path: line.substring(space + 1),
          feature: 'source-only',
        );
      })
      .toList(growable: false);
}
