part of 'sso_client.dart';

extension SSOAdminClientResources on SSOAdminClient {
  Future<SSOAdminListPage> listClients({
    String? pageToken,
    int? pageSize,
    String? orderBy,
    String? filter,
  }) => _listPage(
    '/api/v1/admin/clients',
    'clients',
    pageToken: pageToken,
    pageSize: pageSize,
    orderBy: orderBy,
    filter: filter,
  );

  Future<SSOAdminListPage> listUsers({
    String? pageToken,
    int? pageSize,
    String? orderBy,
    String? filter,
  }) => _listPage(
    '/api/v1/admin/users',
    'users',
    pageToken: pageToken,
    pageSize: pageSize,
    orderBy: orderBy,
    filter: filter,
  );

  Future<SSOAdminListPage> listTenants({
    String? pageToken,
    int? pageSize,
    String? orderBy,
    String? filter,
  }) => _listPage(
    '/api/v1/admin/tenants',
    'tenants',
    pageToken: pageToken,
    pageSize: pageSize,
    orderBy: orderBy,
    filter: filter,
  );

  Future<Map<String, dynamic>> setTenantStatus(String id, String status) async {
    final data = await _post(
      '/api/v1/admin/tenants/${Uri.encodeComponent(id)}:set-status',
      {'status': status},
    );
    return data is Map ? Map<String, dynamic>.from(data) : const {};
  }

  // ---- clients CRUD ----

  Future<Map<String, dynamic>> createClient(Map<String, dynamic> client) async {
    final data =
        await _post('/api/v1/admin/clients', client) as Map<String, dynamic>;
    return (data['client'] as Map<String, dynamic>?) ?? const {};
  }

  Future<Map<String, dynamic>> updateClient(
    String id,
    Map<String, dynamic> client,
  ) async {
    final data =
        await _put('/api/v1/admin/clients/${Uri.encodeComponent(id)}', client)
            as Map<String, dynamic>;
    return (data['client'] as Map<String, dynamic>?) ?? const {};
  }

  Future<void> deleteClient(String id) async {
    await _delete('/api/v1/admin/clients/${Uri.encodeComponent(id)}');
  }

  Future<Map<String, dynamic>> rotateClientSecretWithPolicy(
    String id, {
    Duration? overlap,
    Duration? lifetime,
  }) async {
    final body = <String, dynamic>{};
    if (overlap != null) body['overlap_seconds'] = overlap.inSeconds;
    if (lifetime != null) body['lifetime_seconds'] = lifetime.inSeconds;
    final data =
        await _post(
              '/api/v1/admin/clients/${Uri.encodeComponent(id)}/rotate-secret',
              body,
            )
            as Map<String, dynamic>;
    return data;
  }

  Future<String> rotateClientSecret(String id) async =>
      (await rotateClientSecretWithPolicy(id))['secret'] as String? ?? '';

  Future<List<Map<String, dynamic>>> listExpiringClients({
    Duration? within,
  }) async {
    final query = within == null ? '' : '?within_seconds=${within.inSeconds}';
    final data = await _get('/api/v1/admin/clients/expiring$query');
    final rows = data is Map ? data['clients'] : null;
    return rows is List
        ? rows.whereType<Map>().map(Map<String, dynamic>.from).toList()
        : const [];
  }

  Future<void> approveClient(String id) async {
    await _post(
      '/api/v1/admin/clients/${Uri.encodeComponent(id)}/approve',
      const {},
    );
  }

  Future<void> rejectClient(String id) async {
    await _post(
      '/api/v1/admin/clients/${Uri.encodeComponent(id)}/reject',
      const {},
    );
  }

  Future<Map<String, dynamic>> getClient(String id) async {
    final data =
        await _get('/api/v1/admin/clients/${Uri.encodeComponent(id)}')
            as Map<String, dynamic>;
    return (data['client'] as Map<String, dynamic>?) ?? data;
  }

  Future<Map<String, dynamic>> getUser(String id) async {
    final data =
        await _get('/api/v1/admin/users/${Uri.encodeComponent(id)}')
            as Map<String, dynamic>;
    return (data['user'] as Map<String, dynamic>?) ?? data;
  }

  Future<Map<String, dynamic>> getTenant(String id) async {
    final data =
        await _get('/api/v1/admin/tenants/${Uri.encodeComponent(id)}')
            as Map<String, dynamic>;
    return (data['tenant'] as Map<String, dynamic>?) ?? data;
  }

  // ---- users CRUD ----

  Future<Map<String, dynamic>> createUser(Map<String, dynamic> user) async {
    final data =
        await _post('/api/v1/admin/users', user) as Map<String, dynamic>;
    return (data['user'] as Map<String, dynamic>?) ?? const {};
  }

  Future<Map<String, dynamic>> updateUser(
    String id,
    Map<String, dynamic> user,
  ) async {
    final data =
        await _put('/api/v1/admin/users/${Uri.encodeComponent(id)}', user)
            as Map<String, dynamic>;
    return (data['user'] as Map<String, dynamic>?) ?? const {};
  }

  Future<void> deleteUser(String id) async {
    await _delete('/api/v1/admin/users/${Uri.encodeComponent(id)}');
  }

  // ---- tenants CRUD ----

  Future<Map<String, dynamic>> createTenant(Map<String, dynamic> tenant) async {
    final data =
        await _post('/api/v1/admin/tenants', tenant) as Map<String, dynamic>;
    return (data['tenant'] as Map<String, dynamic>?) ?? const {};
  }

  Future<Map<String, dynamic>> updateTenant(
    String id,
    Map<String, dynamic> tenant,
  ) async {
    final data =
        await _put('/api/v1/admin/tenants/${Uri.encodeComponent(id)}', tenant)
            as Map<String, dynamic>;
    return (data['tenant'] as Map<String, dynamic>?) ?? const {};
  }

  Future<Map<String, dynamic>> deleteTenant(String id) async {
    final data = await _delete(
      '/api/v1/admin/tenants/${Uri.encodeComponent(id)}',
    );
    return data is Map ? Map<String, dynamic>.from(data) : const {};
  }

  /// Fetch a single connection by id.
  Future<Map<String, dynamic>> getConnection(String id) async {
    final data = await _get(
      '/api/v1/admin/connections/${Uri.encodeComponent(id)}',
    );
    return data as Map<String, dynamic>;
  }

  /// Fetch a single break-glass session from the list-only API.
  Future<Map<String, dynamic>> getBreakGlassSession(String id) async {
    return _getCollectionItem(
      path: '/api/v1/admin/break-glass',
      collectionKey: 'sessions',
      id: id,
      identityKeys: const ['id', 'session_id'],
      resourceLabel: 'Break-glass session',
    );
  }

  /// Fetch a single webhook subscription from the list-only API.
  Future<Map<String, dynamic>> getWebhookSubscription(String id) async {
    return _getCollectionItem(
      path: '/api/v1/admin/webhooks/subscriptions',
      collectionKey: 'subscriptions',
      id: id,
      identityKeys: const ['id'],
      resourceLabel: 'Webhook subscription',
    );
  }

  /// Fetch a single domain by hostname.
  Future<Map<String, dynamic>> getDomain(String hostname) async {
    final data = await _get(
      '/api/v1/admin/domains/${Uri.encodeComponent(hostname)}',
    );
    return data as Map<String, dynamic>;
  }

  /// Fetch the active entry for a credential type from the inventory.
  Future<Map<String, dynamic>> getCredential(String type) async {
    return _getCollectionItem(
      path: '/api/v1/admin/credentials',
      collectionKey: 'credentials',
      id: type,
      identityKeys: const ['type', 'id'],
      resourceLabel: 'Credential',
      preferredStatus: 'active',
    );
  }

  /// Fetch a single crypto key from the read-only inventory.
  Future<Map<String, dynamic>> getCryptoKey(String id) async {
    return _getCollectionItem(
      path: '/api/v1/admin/crypto/keys',
      collectionKey: 'keys',
      id: id,
      identityKeys: const ['key_id', 'kid', 'id'],
      resourceLabel: 'Cryptographic key',
    );
  }

  /// Fetch a single access policy from the list-only governance API.
  Future<Map<String, dynamic>> getAccessPolicy(String id) async {
    return _getCollectionItem(
      path: '/api/v1/admin/access-policies',
      collectionKey: 'policies',
      id: id,
      identityKeys: const ['name', 'id'],
      resourceLabel: 'Access policy',
    );
  }

  /// Fetch a single threat policy by id.
  Future<Map<String, dynamic>> getThreatPolicy(String id) async {
    final data = await _get(
      '/api/v1/admin/threat-policies/${Uri.encodeComponent(id)}',
    );
    return data as Map<String, dynamic>;
  }

  /// Create a new identity connection.
  Future<Map<String, dynamic>> createConnection(
    Map<String, dynamic> conn,
  ) async {
    final data = await _post('/api/v1/admin/connections', conn);
    return data as Map<String, dynamic>;
  }

  /// Create or replace a connection through Snaplink's collection upsert.
  Future<Map<String, dynamic>> updateConnection(
    String id,
    Map<String, dynamic> conn,
  ) async {
    final data = await _post('/api/v1/admin/connections', {...conn, 'id': id});
    return data as Map<String, dynamic>;
  }

  /// Delete a connection by id.
  Future<void> deleteConnection(String id) async {
    await _delete('/api/v1/admin/connections/${Uri.encodeComponent(id)}');
  }

  /// Create a new break-glass (emergency access) session.
  Future<Map<String, dynamic>> createBreakGlassSession(
    Map<String, dynamic> session,
  ) async {
    final data = await _post('/api/v1/admin/break-glass', session);
    return data as Map<String, dynamic>;
  }

  /// Delete a break-glass session by id.
  Future<Map<String, dynamic>> deleteBreakGlassSession(String id) async {
    final data = await _delete(
      '/api/v1/admin/break-glass/${Uri.encodeComponent(id)}',
    );
    return data is Map ? Map<String, dynamic>.from(data) : const {};
  }

  /// Create a new webhook subscription.
  Future<Map<String, dynamic>> createWebhookSubscription(
    Map<String, dynamic> sub,
  ) async {
    final data = await _post('/api/v1/admin/webhooks/subscriptions', sub);
    return data as Map<String, dynamic>;
  }

  /// Delete a webhook subscription by id.
  Future<void> deleteWebhookSubscription(String id) async {
    await _delete(
      '/api/v1/admin/webhooks/subscriptions/${Uri.encodeComponent(id)}',
    );
  }

  /// Delete a domain by hostname.
  Future<void> deleteDomain(String hostname) async {
    await _delete('/api/v1/admin/domains/${Uri.encodeComponent(hostname)}');
  }

  /// Report credential compromise by type.
  Future<void> reportCredentialCompromise(String type) async {
    await _post(
      '/api/v1/admin/credentials/${Uri.encodeComponent(type)}/compromise',
      {},
    );
  }

  /// Mark a crypto key as compromised.
  Future<void> compromiseCryptoKey(String id) async {
    await _post(
      '/api/v1/admin/crypto/keys/${Uri.encodeComponent(id)}/compromise',
      {},
    );
  }

  Future<Map<String, dynamic>> _getCollectionItem({
    required String path,
    required String collectionKey,
    required String id,
    required List<String> identityKeys,
    required String resourceLabel,
    String? preferredStatus,
  }) async {
    final data = await _get(path) as Map<String, dynamic>;
    final rawItems = data[collectionKey];
    final matches = rawItems is List
        ? rawItems
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .where(
                (item) =>
                    identityKeys.any((key) => item[key]?.toString() == id),
              )
              .toList(growable: false)
        : const <Map<String, dynamic>>[];
    if (preferredStatus != null) {
      for (final item in matches) {
        if (item['status']?.toString() == preferredStatus) return item;
      }
    }
    if (matches.isNotEmpty) return matches.first;
    throw SSOError(404, 'not_found', '$resourceLabel not found.');
  }
}
