import 'package:sso_admin/api/snaplink_admin_api.dart';

/// Published `chain` envelope, with legacy `chains` and bare-hop support.
/// A null collection is not a hop; malformed collections are source errors.
List<Map<String, dynamic>> tokenExchangeHops(Map<String, dynamic> data) {
  final Object? raw;
  if (data.containsKey('chain')) {
    raw = data['chain'];
  } else if (data.containsKey('chains')) {
    raw = data['chains'];
  } else if (const [
    'subject_id',
    'subject',
    'sub',
    'actor_subject',
    'actor',
    'actor_id',
    'parent_jti',
    'source_jti',
    'target_jti',
    'grant_type',
  ].any(data.containsKey)) {
    raw = [data];
  } else {
    throw const SnaplinkAdminApiError(
      502,
      code: 'invalid_chain_response',
      description: 'The token exchange response has an invalid chain.',
    );
  }
  if (raw == null) return const [];
  if (raw is! List || raw.any((hop) => hop is! Map)) {
    throw const SnaplinkAdminApiError(
      502,
      code: 'invalid_chain_response',
      description: 'The token exchange response has an invalid chain.',
    );
  }
  return [for (final hop in raw) Map<String, dynamic>.from(hop as Map)];
}
