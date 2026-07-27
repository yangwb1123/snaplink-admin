import 'dart:convert';

import 'package:sso_admin/api/snaplink_admin_api.dart';

abstract final class ConnectionAdminContract {
  static const collection = '/api/v1/admin/connections';
  static const detailTemplate = '$collection/:id';
  static const domainsTemplate = '$detailTemplate/domains';
  static const verifyDomainTemplate = '$domainsTemplate/:domain/verify';
  static const healthTemplate = '$detailTemplate/health';
  static const probeTemplate = '$detailTemplate/probe';

  static String detail(String id) => '$collection/${Uri.encodeComponent(id)}';

  static String domains(String id) => '${detail(id)}/domains';

  static String verifyDomain(String id, String domain) =>
      '${domains(id)}/${Uri.encodeComponent(domain)}/verify';

  static String health(String id) => '${detail(id)}/health';

  static String probe(String id) => '${detail(id)}/probe';
}

/// Capability policy for a route family mounted by a single backing store.
///
/// Older replicas can advertise only one representative connection route.
/// Once that family is present, individual requests still rely on the server
/// for method-level authorization.
class ConnectionAdminAvailability {
  final SnaplinkAdminCapabilities capabilities;

  const ConnectionAdminAvailability(this.capabilities);

  bool get familyAvailable =>
      capabilities.hasAnyPathPrefix(ConnectionAdminContract.collection);

  bool supports(String method, String path) =>
      familyAvailable ||
      capabilities.has(method, path) ||
      capabilities.has(
        method,
        path.replaceAll(':id', '{id}').replaceAll(':domain', '{domain}'),
      );

  bool get canList => supports('GET', ConnectionAdminContract.collection);
  bool get canCreate => supports('POST', ConnectionAdminContract.collection);
  bool get canGet => supports('GET', ConnectionAdminContract.detailTemplate);
  bool get canDelete =>
      supports('DELETE', ConnectionAdminContract.detailTemplate);
  bool get canListDomains =>
      supports('GET', ConnectionAdminContract.domainsTemplate);
  bool get canVerifyDomain =>
      supports('POST', ConnectionAdminContract.verifyDomainTemplate);
  bool get canReadHealth =>
      supports('GET', ConnectionAdminContract.healthTemplate);
  bool get canProbe => supports('POST', ConnectionAdminContract.probeTemplate);
}

class ConnectionConfigurationNotObject implements Exception {
  const ConnectionConfigurationNotObject();
}

Map<String, String> decodeConnectionConfiguration(String input) {
  final raw = input.trim();
  if (raw.isEmpty) return const {};
  final decoded = jsonDecode(raw);
  if (decoded is! Map) throw const ConnectionConfigurationNotObject();
  return decoded.map(
    (key, value) => MapEntry(key.toString(), value.toString()),
  );
}
