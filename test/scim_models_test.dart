import 'package:flutter_test/flutter_test.dart';
import 'package:sso_admin/screens/admin/scim/scim_models.dart';

void main() {
  group('SCIM discovery models', () {
    test('parses advertised capabilities and bounded limits', () {
      final profile = ScimServiceProfile.fromJson({
        'patch': {'supported': true},
        'filter': {'supported': true, 'maxResults': 200},
        'bulk': {
          'supported': true,
          'maxOperations': 1000,
          'maxPayloadSize': 1048576,
        },
        'sort': {'supported': true},
        'etag': {'supported': true},
        'changePassword': {'supported': false},
        'authenticationSchemes': [
          {'name': 'OAuth Bearer Token'},
        ],
      });

      expect(profile.patch, isTrue);
      expect(profile.filterMaxResults, 200);
      expect(profile.bulkMaxOperations, 1000);
      expect(profile.bulkMaxPayloadSize, 1048576);
      expect(profile.changePassword, isFalse);
      expect(profile.authenticationSchemes, ['OAuth Bearer Token']);
    });

    test('parses the RFC ListResponse pagination envelope', () {
      final page = ScimListPage.fromJson({
        'totalResults': 75,
        'startIndex': 26,
        'itemsPerPage': 25,
        'Resources': [
          {'id': 'u-26', 'userName': 'ada'},
        ],
      });

      expect(page.resources.single['id'], 'u-26');
      expect(page.hasPrevious, isTrue);
      expect(page.hasNext, isTrue);
    });
  });

  group('SCIM structured request models', () {
    test('builds a user with core and enterprise schema fields', () {
      const draft = ScimUserDraft(
        userName: 'ada@example.test',
        displayName: 'Ada Lovelace',
        externalId: 'hr-42',
        active: true,
        name: {'givenName': 'Ada', 'familyName': 'Lovelace'},
        emails: [
          {'value': 'ada@example.test', 'type': 'work', 'primary': true},
        ],
        enterprise: {
          'department': 'Research',
          'manager': {'value': 'u-manager'},
        },
      );

      final body = draft.toJson();

      expect(body['schemas'], [scimUserSchema, scimEnterpriseUserSchema]);
      expect(body['userName'], 'ada@example.test');
      expect(body['name'], {'givenName': 'Ada', 'familyName': 'Lovelace'});
      expect(
        body[scimEnterpriseUserSchema],
        containsPair('department', 'Research'),
      );
      expect(body, isNot(contains('id')));
    });

    test('builds a group membership replacement body', () {
      const draft = ScimGroupDraft(
        displayName: 'Operators',
        memberIds: ['u-1', 'u-2'],
      );

      expect(draft.toJson(), {
        'schemas': [scimGroupSchema],
        'displayName': 'Operators',
        'members': [
          {'value': 'u-1', 'type': 'User'},
          {'value': 'u-2', 'type': 'User'},
        ],
      });
    });

    test('builds a non-empty ordered PatchOp envelope', () {
      final body = scimPatchBody(const [
        ScimPatchOperation(op: 'replace', path: 'active', value: false),
        ScimPatchOperation(op: 'remove', path: 'externalId'),
      ]);

      expect(body['schemas'], [scimPatchSchema]);
      expect(body['Operations'], [
        {'op': 'replace', 'path': 'active', 'value': false},
        {'op': 'remove', 'path': 'externalId'},
      ]);
      expect(() => scimPatchBody(const []), throwsArgumentError);
    });
  });

  group('SCIM Bulk validation', () {
    const valid = '''
{
  "schemas": ["urn:ietf:params:scim:api:messages:2.0:BulkRequest"],
  "failOnErrors": 1,
  "Operations": [
    {
      "method": "POST",
      "bulkId": "new-user",
      "path": "/Users",
      "data": {"userName": "ada@example.test"}
    },
    {
      "method": "DELETE",
      "path": "/Groups/old-group"
    }
  ]
}
''';

    test('previews count, methods, and payload before execution', () {
      final preview = ScimBulkPreview.parse(
        valid,
        maxOperations: 10,
        maxPayloadSize: 4096,
      );

      expect(preview.isValid, isTrue);
      expect(preview.operationCount, 2);
      expect(preview.methodCounts, {'POST': 1, 'DELETE': 1});
      expect(preview.payloadBytes, greaterThan(0));
    });

    test('rejects empty, malformed, unbounded, and recursive requests', () {
      expect(
        ScimBulkPreview.parse(
          '',
          maxOperations: 10,
          maxPayloadSize: 100,
        ).isValid,
        isFalse,
      );
      expect(
        ScimBulkPreview.parse(
          '{',
          maxOperations: 10,
          maxPayloadSize: 100,
        ).error,
        contains('Invalid JSON'),
      );
      expect(
        ScimBulkPreview.parse(
          valid,
          maxOperations: 1,
          maxPayloadSize: 4096,
        ).error,
        contains('exceed'),
      );
      expect(
        ScimBulkPreview.parse(
          valid,
          maxOperations: 10,
          maxPayloadSize: 10,
        ).error,
        contains('server limit'),
      );
      expect(
        ScimBulkPreview.parse(
          '{"schemas":["$scimBulkRequestSchema"],'
          '"Operations":[{"method":"POST","bulkId":"x","path":"/Bulk"}]}',
          maxOperations: 10,
          maxPayloadSize: 4096,
        ).error,
        contains('/Users or /Groups'),
      );
    });

    test('requires bulkId on POST operations', () {
      final preview = ScimBulkPreview.parse(
        '{"schemas":["$scimBulkRequestSchema"],'
        '"Operations":[{"method":"POST","path":"/Users"}]}',
        maxOperations: 10,
        maxPayloadSize: 4096,
      );

      expect(preview.isValid, isFalse);
      expect(preview.error, contains('requires bulkId'));
    });

    test('rejects credentials in the retained expert editor', () {
      final preview = ScimBulkPreview.parse(
        '{"schemas":["$scimBulkRequestSchema"],'
        '"Operations":[{"method":"POST","bulkId":"x","path":"/Users",'
        '"data":{"userName":"ada","password":"do-not-retain"}}]}',
        maxOperations: 10,
        maxPayloadSize: 4096,
      );

      expect(preview.isValid, isFalse);
      expect(preview.error, contains('Credential fields'));
    });
  });
}
