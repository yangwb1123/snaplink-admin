// Published admin/v1 protojson: camelCase fields and quoted int64 values.
const fixtureClient = {
  'id': 'client-1',
  'name': 'Contract client',
  'active': true,
  'tokenStrategy': 'jwt',
  'redirectUris': ['https://app.example.test/callback'],
  'allowedScopes': ['openid'],
  'allowedAuthenticators': ['password'],
  'clientSecretExpiresAt': '1900000000',
  'loginPageUri': 'https://sso.example.test/login/',
  'tenantId': 'tenant-1',
  'grantTypes': ['authorization_code'],
};
const fixtureUser = {
  'id': 'user-1',
  'externalId': 'external-1',
  'provider': 'fixture',
  'attributes': {
    'name': 'Contract user',
    'email': 'fixture@example.test',
    'tenantId': 'opaque-attribute',
  },
};
const fixtureTenant = {
  'id': 'tenant-1',
  'name': 'Contract tenant',
  'slug': 'contract',
  'status': 'active',
  'homeRegion': 'eu-west',
  'allowedRegions': ['eu-west'],
  'enforceWrites': true,
  'settings': {'homeRegion': 'opaque-setting'},
};
const fixtureSnapshot = {
  'snapshotId': 'snapshot-1',
  'schemaVersion': 1,
  'takenAtUnix': '1700000000',
  'sourceNamespace': 'fixture',
  'sourceNodeId': 'node-1',
  'sizeBytes': '1024',
  'codec': 'json',
  'bootstrapAppliedVersion': 1,
};
const fixtureRelease = {
  'id': 'release-1',
  'channel': 'stable',
  'schemaVersion': 1,
  'frontend': {'gitRef': 'frontend-ref'},
  'backend': {'gitRef': 'backend-ref'},
  'releasedAtUnix': '1700000000',
  'releasedBy': 'fixture-operator',
};

const protoResponses = <String, Object>{
  '/api/v1/admin/clients': {
    'nextPageToken': '',
    'totalSize': 1,
    'clients': [fixtureClient],
  },
  '/api/v1/admin/clients/expiring': {
    'nextPageToken': '',
    'totalSize': 1,
    'clients': [fixtureClient],
  },
  '/api/v1/admin/clients/client-1': {'client': fixtureClient},
  '/api/v1/admin/users': {
    'nextPageToken': '',
    'totalSize': 1,
    'users': [fixtureUser],
  },
  '/api/v1/admin/users/user-1': {'user': fixtureUser},
  '/api/v1/admin/tenants': {
    'nextPageToken': '',
    'totalSize': 1,
    'tenants': [fixtureTenant],
  },
  '/api/v1/admin/tenants/tenant-1': {'tenant': fixtureTenant},
  '/api/v1/admin/domains': {
    'nextPageToken': '',
    'totalSize': 1,
    'domains': [
      {'hostname': 'example.test', 'tenantId': 'tenant-1', 'isApex': true},
    ],
  },
  '/api/v1/admin/domains/example.test': {
    'domain': {
      'hostname': 'example.test',
      'tenantId': 'tenant-1',
      'isApex': true,
    },
  },
  '/api/v1/admin/keys': {
    'keys': [
      {'kid': 'key-1', 'alg': 'RS256', 'state': 'active'},
    ],
  },
  '/api/v1/admin/permissions/client-1/roles': {
    'nextPageToken': '',
    'totalSize': 1,
    'roles': [
      {
        'code': 'viewer',
        'name': 'Contract role',
        'permissions': ['read'],
      },
    ],
  },
  '/api/v1/admin/permissions/client-1/assignments': {
    'nextPageToken': '',
    'totalSize': 1,
    'assignments': [
      {
        'userId': 'user-1',
        'roles': ['viewer'],
      },
    ],
  },
  '/api/v1/admin/users/user-1/sessions': {
    'nextPageToken': '',
    'totalSize': 1,
    'sessions': [
      {
        'id': 'session-1',
        'userId': 'user-1',
        'createdAtUnix': '1700000000',
        'expiresAtUnix': '1900000000',
        'revoked': false,
      },
    ],
  },
  '/api/v1/admin/snapshots': {
    'nextPageToken': '',
    'totalSize': 1,
    'items': [fixtureSnapshot],
  },
  '/api/v1/admin/releases': {
    'nextPageToken': '',
    'totalSize': 1,
    'items': [fixtureRelease],
  },
  '/api/v1/admin/releases:current': {'release': fixtureRelease},
  '/api/v1/admin/operations': {
    'nextPageToken': '',
    'totalSize': 1,
    'operations': [
      {
        'id': 'operation-1',
        'kind': 'restore',
        'state': 'completed',
        'currentStep': 'done',
      },
    ],
  },
};
