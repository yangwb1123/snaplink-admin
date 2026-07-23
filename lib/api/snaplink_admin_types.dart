import 'dart:typed_data';

/// One route in Snaplink's runtime inventory (`GET /api/v1/admin/endpoints`).
///
/// Unlike a build-time list, this is the source of truth for the replica the
/// operator is connected to: routes behind a disabled feature gate or an
/// unwired optional store are absent.
class SnaplinkAdminEndpoint {
  final String method;
  final String path;
  final String feature;

  const SnaplinkAdminEndpoint({
    required this.method,
    required this.path,
    required this.feature,
  });

  factory SnaplinkAdminEndpoint.fromJson(Map<String, dynamic> json) =>
      SnaplinkAdminEndpoint(
        method: json['method']?.toString().toUpperCase() ?? '',
        path: json['path']?.toString() ?? '',
        feature: json['feature']?.toString() ?? 'core',
      );

  List<String> get pathParameters {
    final names = <String>{
      ...RegExp(
        r'\{([A-Za-z_][A-Za-z0-9_]*)\}',
      ).allMatches(path).map((match) => match.group(1)!),
      ...path
          .split('/')
          .where((segment) => segment.startsWith(':'))
          .map((segment) => segment.substring(1).split(':').first),
    };
    return names.toList(growable: false);
  }

  String resolvePath(Map<String, String> values) {
    var resolved = path;
    for (final parameter in pathParameters) {
      final value = values[parameter]?.trim() ?? '';
      if (value.isEmpty) {
        throw ArgumentError.value(
          parameter,
          'values',
          'A path value is required',
        );
      }
      final encoded = Uri.encodeComponent(value);
      if (resolved.contains('{$parameter}')) {
        resolved = resolved.replaceFirst('{$parameter}', encoded);
      } else {
        resolved = resolved.replaceFirst('/:$parameter', '/$encoded');
      }
    }
    return resolved;
  }
}

/// A redacted notification from Snaplink's admin Server-Sent Events feed.
class SnaplinkAdminEvent {
  final String? id;
  final String type;
  final Map<String, dynamic> data;

  const SnaplinkAdminEvent({
    required this.id,
    required this.type,
    required this.data,
  });
}

/// A server-produced export that must be handled as an attachment, not shown
/// in the console or copied to an operator's clipboard.
class SnaplinkAdminDownload {
  final Uint8List bytes;
  final String contentType;
  final String? filename;

  const SnaplinkAdminDownload({
    required this.bytes,
    required this.contentType,
    required this.filename,
  });
}

/// Small query helper shared by capability-aware admin screens.
class SnaplinkAdminCapabilities {
  final List<SnaplinkAdminEndpoint> endpoints;

  const SnaplinkAdminCapabilities(this.endpoints);

  bool has(String method, String path) => endpoints.any(
    (endpoint) =>
        endpoint.method == method.toUpperCase() && endpoint.path == path,
  );

  bool hasAnyPathPrefix(String prefix) =>
      endpoints.any((endpoint) => endpoint.path.startsWith(prefix));

  Map<String, int> get featureCounts {
    final counts = <String, int>{};
    for (final endpoint in endpoints) {
      counts.update(endpoint.feature, (count) => count + 1, ifAbsent: () => 1);
    }
    return counts;
  }
}
