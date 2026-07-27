import 'dart:convert';

import 'package:sso_admin/services/sensitive_data.dart';

const scimContentType = 'application/scim+json';
const scimBasePath = '/api/v1/scim/v2';
const scimUserSchema = 'urn:ietf:params:scim:schemas:core:2.0:User';
const scimGroupSchema = 'urn:ietf:params:scim:schemas:core:2.0:Group';
const scimEnterpriseUserSchema =
    'urn:ietf:params:scim:schemas:extension:enterprise:2.0:User';
const scimPatchSchema = 'urn:ietf:params:scim:api:messages:2.0:PatchOp';
const scimBulkRequestSchema =
    'urn:ietf:params:scim:api:messages:2.0:BulkRequest';

enum ScimResourceKind {
  users('Users', 'User', scimUserSchema),
  groups('Groups', 'Group', scimGroupSchema);

  final String collection;
  final String singular;
  final String schema;

  const ScimResourceKind(this.collection, this.singular, this.schema);

  String get path => '$scimBasePath/$collection';

  List<String> get sortAttributes => this == ScimResourceKind.users
      ? const ['userName', 'displayName', 'externalId', 'meta.lastModified']
      : const ['displayName', 'id'];
}

class ScimListPage {
  final List<Map<String, dynamic>> resources;
  final int totalResults;
  final int startIndex;
  final int itemsPerPage;

  const ScimListPage({
    required this.resources,
    required this.totalResults,
    required this.startIndex,
    required this.itemsPerPage,
  });

  factory ScimListPage.fromJson(Map<String, dynamic> json) {
    final resources = (json['Resources'] as List? ?? const [])
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList(growable: false);
    return ScimListPage(
      resources: resources,
      totalResults: (json['totalResults'] as num?)?.toInt() ?? resources.length,
      startIndex: (json['startIndex'] as num?)?.toInt() ?? 1,
      itemsPerPage: (json['itemsPerPage'] as num?)?.toInt() ?? resources.length,
    );
  }

  bool get hasPrevious => startIndex > 1;
  bool get hasNext => startIndex + itemsPerPage <= totalResults;
}

class ScimServiceProfile {
  final bool patch;
  final bool filter;
  final bool bulk;
  final bool sort;
  final bool etag;
  final bool changePassword;
  final int filterMaxResults;
  final int bulkMaxOperations;
  final int bulkMaxPayloadSize;
  final List<String> authenticationSchemes;

  const ScimServiceProfile({
    required this.patch,
    required this.filter,
    required this.bulk,
    required this.sort,
    required this.etag,
    required this.changePassword,
    required this.filterMaxResults,
    required this.bulkMaxOperations,
    required this.bulkMaxPayloadSize,
    required this.authenticationSchemes,
  });

  factory ScimServiceProfile.fromJson(Map<String, dynamic> json) {
    final bulk = _map(json['bulk']);
    final filter = _map(json['filter']);
    final schemes = (json['authenticationSchemes'] as List? ?? const [])
        .whereType<Map>()
        .map((value) => value['name']?.toString() ?? '')
        .where((value) => value.isNotEmpty)
        .toList(growable: false);
    return ScimServiceProfile(
      patch: _supported(json['patch']),
      filter: _supported(filter),
      bulk: _supported(bulk),
      sort: _supported(json['sort']),
      etag: _supported(json['etag']),
      changePassword: _supported(json['changePassword']),
      filterMaxResults: (filter['maxResults'] as num?)?.toInt() ?? 200,
      bulkMaxOperations: (bulk['maxOperations'] as num?)?.toInt() ?? 1000,
      bulkMaxPayloadSize:
          (bulk['maxPayloadSize'] as num?)?.toInt() ?? 1024 * 1024,
      authenticationSchemes: schemes,
    );
  }

  static bool _supported(Object? value) =>
      value is Map && value['supported'] == true;
}

class ScimUserDraft {
  final String userName;
  final String displayName;
  final String externalId;
  final bool active;
  final Map<String, String> name;
  final List<Map<String, dynamic>> emails;
  final Map<String, dynamic> enterprise;

  const ScimUserDraft({
    required this.userName,
    required this.displayName,
    required this.externalId,
    required this.active,
    required this.name,
    required this.emails,
    required this.enterprise,
  });

  Map<String, dynamic> toJson() {
    final hasEnterprise = enterprise.values.any(
      (value) => value is Map ? value.isNotEmpty : value.toString().isNotEmpty,
    );
    return {
      'schemas': [scimUserSchema, if (hasEnterprise) scimEnterpriseUserSchema],
      'userName': userName,
      if (displayName.isNotEmpty) 'displayName': displayName,
      if (externalId.isNotEmpty) 'externalId': externalId,
      'active': active,
      if (name.values.any((value) => value.isNotEmpty))
        'name': Map.fromEntries(
          name.entries.where((entry) => entry.value.isNotEmpty),
        ),
      if (emails.isNotEmpty) 'emails': emails,
      if (hasEnterprise) scimEnterpriseUserSchema: enterprise,
    };
  }
}

class ScimGroupDraft {
  final String displayName;
  final List<String> memberIds;

  const ScimGroupDraft({required this.displayName, required this.memberIds});

  Map<String, dynamic> toJson() => {
    'schemas': const [scimGroupSchema],
    'displayName': displayName,
    if (memberIds.isNotEmpty)
      'members': memberIds
          .map((id) => {'value': id, 'type': 'User'})
          .toList(growable: false),
  };
}

class ScimPatchOperation {
  final String op;
  final String path;
  final Object? value;

  const ScimPatchOperation({required this.op, required this.path, this.value});

  Map<String, dynamic> toJson() => {
    'op': op,
    'path': path,
    if (op != 'remove' || value != null) 'value': value,
  };
}

Map<String, dynamic> scimPatchBody(List<ScimPatchOperation> operations) {
  if (operations.isEmpty) {
    throw ArgumentError.value(operations, 'operations', 'must not be empty');
  }
  return {
    'schemas': const [scimPatchSchema],
    'Operations': operations.map((operation) => operation.toJson()).toList(),
  };
}

class ScimBulkPreview {
  final Map<String, dynamic>? body;
  final String? error;
  final int operationCount;
  final int payloadBytes;
  final Map<String, int> methodCounts;

  const ScimBulkPreview._({
    this.body,
    this.error,
    required this.operationCount,
    required this.payloadBytes,
    required this.methodCounts,
  });

  bool get isValid => body != null && error == null;

  factory ScimBulkPreview.parse(
    String source, {
    required int maxOperations,
    required int maxPayloadSize,
  }) {
    final trimmed = source.trim();
    final bytes = utf8.encode(trimmed).length;
    if (trimmed.isEmpty) {
      return _invalid('Bulk JSON is required.', bytes);
    }
    if (bytes > maxPayloadSize) {
      return _invalid(
        'Payload is $bytes bytes; the server limit is $maxPayloadSize.',
        bytes,
      );
    }
    Object? decoded;
    try {
      decoded = jsonDecode(trimmed);
    } on FormatException catch (error) {
      return _invalid('Invalid JSON: ${error.message}', bytes);
    }
    if (decoded is! Map) {
      return _invalid('BulkRequest must be a JSON object.', bytes);
    }
    final body = Map<String, dynamic>.from(decoded);
    if (SensitiveData.containsSensitiveField(body)) {
      return _invalid(
        'Credential fields are not allowed in the retained bulk editor.',
        bytes,
      );
    }
    final schemas = body['schemas'];
    if (schemas is! List || !schemas.contains(scimBulkRequestSchema)) {
      return _invalid('schemas must include the BulkRequest URN.', bytes);
    }
    final rawOperations = body['Operations'];
    if (rawOperations is! List || rawOperations.isEmpty) {
      return _invalid('Operations must be a non-empty array.', bytes);
    }
    if (rawOperations.length > maxOperations) {
      return _invalid(
        '${rawOperations.length} operations exceed the server limit of '
        '$maxOperations.',
        bytes,
      );
    }
    final counts = <String, int>{};
    for (var index = 0; index < rawOperations.length; index++) {
      final raw = rawOperations[index];
      if (raw is! Map) {
        return _invalid('Operation ${index + 1} must be an object.', bytes);
      }
      final method = raw['method']?.toString().toUpperCase() ?? '';
      final path = raw['path']?.toString().trim() ?? '';
      if (!const ['POST', 'PUT', 'PATCH', 'DELETE'].contains(method)) {
        return _invalid('Operation ${index + 1} has an invalid method.', bytes);
      }
      if (!_validBulkPath(path)) {
        return _invalid(
          'Operation ${index + 1} must target /Users or /Groups.',
          bytes,
        );
      }
      if (method == 'POST' &&
          (raw['bulkId']?.toString().trim().isEmpty ?? true)) {
        return _invalid('POST operation ${index + 1} requires bulkId.', bytes);
      }
      counts.update(method, (value) => value + 1, ifAbsent: () => 1);
    }
    return ScimBulkPreview._(
      body: body,
      operationCount: rawOperations.length,
      payloadBytes: bytes,
      methodCounts: counts,
    );
  }

  static ScimBulkPreview _invalid(String error, int bytes) => ScimBulkPreview._(
    error: error,
    operationCount: 0,
    payloadBytes: bytes,
    methodCounts: const {},
  );

  static bool _validBulkPath(String path) =>
      path == '/Users' ||
      path.startsWith('/Users/') ||
      path == '/Groups' ||
      path.startsWith('/Groups/');
}

Map<String, dynamic> _map(Object? value) =>
    value is Map ? Map<String, dynamic>.from(value) : const {};
