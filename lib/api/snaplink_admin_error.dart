import 'dart:convert';

/// A non-successful response from Snaplink's admin surface.
///
/// The API deliberately keeps the server's structured error fields so UI
/// callers can show a useful operational message without guessing from a
/// status code. Credential values are never retained here.
class SnaplinkAdminApiError implements Exception {
  final int status;
  final String? code;
  final String? description;
  final Map<String, dynamic> data;

  const SnaplinkAdminApiError(
    this.status, {
    this.code,
    this.description,
    this.data = const {},
  });

  /// A 403 means this bearer is valid but does not hold the requested scope
  /// (or is outside the requested tenant boundary), so it must not destroy a
  /// still-valid console session.
  bool get isUnauthorized => status == 401;

  /// Durable mutation failures carry a google.rpc.ErrorInfo detail so the
  /// operator can reconcile the exact server-owned operation after a lost or
  /// failed response.
  String? get operationId {
    final direct = data['operation_id']?.toString();
    if (direct != null && direct.isNotEmpty) return direct;
    final details = data['details'];
    if (details is! List) return null;
    for (final detail in details.whereType<Map>()) {
      final metadata = detail['metadata'];
      if (metadata is! Map) continue;
      final value = metadata['operation_id']?.toString();
      if (value != null && value.isNotEmpty) return value;
    }
    return null;
  }

  @override
  String toString() {
    if (description != null) return description!;
    if (code != null) return code!;
    // Platform convention: a 403 proves the bearer is valid but under-scoped
    // (or outside the tenant boundary), so the console keeps the session and
    // shows a permission denial instead of treating it like an expired
    // session (401 ends the session; 403 never does).
    if (status == 403) {
      return 'This session is not authorized for this operation (403).';
    }
    return 'Admin request failed ($status).';
  }
}

/// Decodes only JSON objects and deliberately discards proxy error pages.
Map<String, dynamic> decodeSnaplinkAdminPayload(String payload) {
  if (payload.isEmpty) return const {};
  try {
    final decoded = jsonDecode(payload);
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
  } on FormatException {
    // The status code remains authoritative. Returning an empty object also
    // prevents an HTML proxy response from being surfaced in the operator UI.
  }
  return const {};
}

/// Maps OAuth, generic API, and RFC 7644 SCIM errors into one public shape.
SnaplinkAdminApiError snaplinkAdminError(
  int status,
  Map<String, dynamic> data,
) {
  return SnaplinkAdminApiError(
    status,
    code:
        data['error']?.toString() ??
        data['code']?.toString() ??
        data['scimType']?.toString(),
    description:
        data['error_description']?.toString() ??
        data['message']?.toString() ??
        data['detail']?.toString(),
    data: Map<String, dynamic>.unmodifiable(data),
  );
}
