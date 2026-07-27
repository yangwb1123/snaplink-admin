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

  const SnaplinkAdminApiError(this.status, {this.code, this.description});

  /// A 403 means this bearer is valid but does not hold the requested scope
  /// (or is outside the requested tenant boundary), so it must not destroy a
  /// still-valid console session.
  bool get isUnauthorized => status == 401;

  @override
  String toString() => description ?? code ?? 'Admin request failed ($status).';
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
  );
}
