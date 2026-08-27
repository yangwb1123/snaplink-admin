part of 'sso_client.dart';

extension SSOAdminClientSession on SSOAdminClient {
  Future<Map<String, dynamic>> login(
    String username,
    String password, {
    String clientId = SSOAdminClient.firstPartyClientId,
    List<String>? resources,
  }) async {
    final requestedResources = resources ?? AdminOAuthResources.values;
    final body = await _post('/auth/login', {
      'provider': 'password',
      'client_id': clientId,
      'scope': ['openid', 'profile', 'admin:read', 'admin:write'],
      if (requestedResources.isNotEmpty) 'resource': requestedResources,
      'credential': {'username': username, 'password': password},
    }, auth: false);
    final map = body as Map<String, dynamic>;
    if (map['access_token'] != null) {
      _token = map['access_token'] as String;
    }
    return map;
  }

  void logout() {
    _token = null;
  }

  /// Verifies the bearer has read access to the admin control plane without
  /// coupling entry authorization to any managed resource collection.
  Future<void> probeAdminAccess() async {
    await _get('/api/v1/admin/endpoints');
  }
}
