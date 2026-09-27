import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:sso_admin/api/forge_device_inventory_declaration.dart';
import 'package:sso_admin/api/forge_client_instance_session_resource_convergence.dart';
import 'package:sso_admin/api/forge_run_attempt_lease_dispatch_preflight.dart';
import 'package:sso_admin/screens/forge/forge_sessions_gate.dart';
import 'package:sso_admin/services/browser_navigation.dart';
import 'package:sso_admin/services/forge_credential_store.dart';
import 'package:sso_admin/session.dart';

import 'support/memory_forge_credential_backend.dart';

const _owner = ForgeDeviceOwner(
  issuer: 'https://id.example',
  subject: 'user-1',
  tenantID: 'tenant-1',
);

http.Response _json(Object value, {int status = 200}) => http.Response(
  jsonEncode(value),
  status,
  headers: const {'content-type': 'application/json'},
);

void main() {
  setUpAll(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  setUp(() => BrowserNavigation.resetForTest());

  tearDown(() {
    BrowserNavigation.resetForTest();
    Session.clear();
  });

  testWidgets(
    'explicit Gate candidate posts one owner-bound preflight with bearer auth',
    (tester) async {
      final credentialStore = await _credentialStore('candidate-token');
      final request = _request();
      final requests = <http.Request>[];
      final client = MockClient((http.Request httpRequest) async {
        requests.add(httpRequest);
        if (httpRequest.method == 'GET' &&
            httpRequest.url.path == '/api/v1/conversations') {
          return _json({
            'conversations': [_conversation()],
            'has_more': false,
          });
        }
        if (httpRequest.method == 'GET' &&
            httpRequest.url.path ==
                '/api/v1/conversations/conversation-001/prompts') {
          return _json({
            'conversation_id': 'conversation-001',
            'prompts': <Object>[],
            'has_more': false,
          });
        }
        if (httpRequest.method == 'GET' &&
            httpRequest.url.path ==
                '/api/v1/conversations/conversation-001/runs') {
          return _json({
            'conversation_id': 'conversation-001',
            'runs': [_run()],
            'has_more': false,
          });
        }
        if (httpRequest.method == 'GET' &&
            httpRequest.url.path ==
                '/api/v1/conversations/conversation-001/runs/run-001/timeline') {
          return _json({
            'conversation_id': 'conversation-001',
            'run_id': 'run-001',
            'after_sequence': 0,
            'scanned_through_sequence': 0,
            'has_more': false,
            'events': <Object>[],
          });
        }
        if (httpRequest.method == 'POST' &&
            httpRequest.url.path ==
                '/api/v1/conversations/conversation-001/runs/run-001/attempt-lease-dispatch-preflight/preview') {
          expect(
            httpRequest.headers['authorization'],
            'Bearer candidate-token',
          );
          expect(jsonDecode(httpRequest.body), request.toJson());
          return _json(_response());
        }
        throw StateError(
          'Unexpected Forge request: ${httpRequest.method} ${httpRequest.url}',
        );
      });
      addTearDown(client.close);

      await tester.pumpWidget(
        MaterialApp(
          home: ForgeSessionsGate(
            credentialStore: credentialStore,
            httpClient: client,
            runAttemptLeaseDispatchPreflightRequest: request,
            enableRunAttemptLeaseDispatchPreflightCandidate: true,
            runAttemptLeaseDispatchPreflightCandidateApiOrigin:
                'https://candidate.example',
          ),
        ),
      );
      await _settle(tester);

      await tester.scrollUntilVisible(
        find.text('Forge preflight preview'),
        500,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Forge preflight preview'), findsOneWidget);
      expect(find.text('Preview only · no dispatch performed'), findsOneWidget);
      final preflightRequests = requests
          .where(
            (value) =>
                value.url.path.contains('attempt-lease-dispatch-preflight'),
          )
          .toList();
      expect(preflightRequests, hasLength(1));
      expect(preflightRequests.single.method, 'POST');
    },
  );

  testWidgets(
    'candidate flag remains request-free without an explicit typed request',
    (tester) async {
      final credentialStore = await _credentialStore('disabled-token');
      final requests = <http.Request>[];
      final client = MockClient((request) async {
        requests.add(request);
        if (request.method == 'GET' &&
            request.url.path == '/api/v1/conversations') {
          return _json({'conversations': <Object>[], 'has_more': false});
        }
        throw StateError(
          'Candidate route must remain disabled: ${request.url}',
        );
      });
      addTearDown(client.close);

      await tester.pumpWidget(
        MaterialApp(
          home: ForgeSessionsGate(
            credentialStore: credentialStore,
            httpClient: client,
            enableRunAttemptLeaseDispatchPreflightCandidate: true,
            runAttemptLeaseDispatchPreflightCandidateApiOrigin:
                'https://candidate.example',
          ),
        ),
      );
      await _settle(tester);

      expect(
        requests.where(
          (request) =>
              request.url.path.contains('attempt-lease-dispatch-preflight'),
        ),
        isEmpty,
      );
      expect(requests, hasLength(1));
    },
  );

  testWidgets(
    'preflight reads the selected client-instance pair before one candidate POST',
    (tester) async {
      final credentialStore = await _credentialStore(
        'instance-preflight-token',
      );
      final request = _request();
      final pair = _clientInstancePair();
      final events = <String>[];
      final candidateRequests = <http.Request>[];
      final client = MockClient((httpRequest) async {
        if (httpRequest.method == 'GET' &&
            httpRequest.url.path == '/api/v1/conversations') {
          return _json({
            'conversations': [_conversation()],
            'has_more': false,
          });
        }
        if (httpRequest.method == 'GET' &&
            httpRequest.url.path ==
                '/api/v1/conversations/conversation-001/prompts') {
          return _json({
            'conversation_id': 'conversation-001',
            'prompts': <Object>[],
            'has_more': false,
          });
        }
        if (httpRequest.method == 'GET' &&
            httpRequest.url.path ==
                '/api/v1/conversations/conversation-001/runs') {
          return _json({
            'conversation_id': 'conversation-001',
            'runs': [_run()],
            'has_more': false,
          });
        }
        if (httpRequest.method == 'GET' &&
            httpRequest.url.path ==
                '/api/v1/conversations/conversation-001/runs/run-001/timeline') {
          return _json({
            'conversation_id': 'conversation-001',
            'run_id': 'run-001',
            'after_sequence': 0,
            'scanned_through_sequence': 0,
            'has_more': false,
            'events': <Object>[],
          });
        }
        if (httpRequest.method == 'POST' &&
            httpRequest.url.path ==
                '/api/v1/conversations/conversation-001/runs/run-001/attempt-lease-dispatch-preflight/preview') {
          events.add('candidate');
          candidateRequests.add(httpRequest);
          expect(jsonDecode(httpRequest.body), request.toJson());
          return _json(_response());
        }
        throw StateError(
          'Unexpected Forge request: ${httpRequest.method} ${httpRequest.url}',
        );
      });
      addTearDown(client.close);
      addTearDown(credentialStore.clear);

      await tester.pumpWidget(
        MaterialApp(
          home: ForgeSessionsGate(
            credentialStore: credentialStore,
            httpClient: client,
            initialConversationID: 'conversation-001',
            initialClientInstanceID: 'client-cli-001',
            clientInstanceSessionResourceConvergenceOwner: _owner,
            clientInstanceSessionResourceConvergenceReader: (_) async {
              events.add('client-instance-pair');
              return pair;
            },
            runAttemptLeaseDispatchPreflightRequest: request,
            enableRunAttemptLeaseDispatchPreflightCandidate: true,
            runAttemptLeaseDispatchPreflightCandidateApiOrigin:
                'https://candidate.example',
          ),
        ),
      );
      await _settle(tester);

      expect(candidateRequests, hasLength(1));
      final candidateIndex = events.indexOf('candidate');
      expect(candidateIndex, greaterThan(0));
      expect(
        events.sublist(0, candidateIndex),
        everyElement('client-instance-pair'),
      );
    },
  );

  testWidgets(
    'preflight stays request-free when the selected instance hides the Run',
    (tester) async {
      final credentialStore = await _credentialStore(
        'hidden-instance-preflight-token',
      );
      final request = _request();
      var pairReads = 0;
      final candidateRequests = <http.Request>[];
      final client = MockClient((httpRequest) async {
        if (httpRequest.method == 'GET' &&
            httpRequest.url.path == '/api/v1/conversations') {
          return _json({
            'conversations': [_conversation()],
            'has_more': false,
          });
        }
        if (httpRequest.method == 'GET' &&
            httpRequest.url.path.contains('/prompts')) {
          return _json({
            'conversation_id': 'conversation-001',
            'prompts': <Object>[],
            'has_more': false,
          });
        }
        if (httpRequest.method == 'GET' &&
            httpRequest.url.path.endsWith('/runs')) {
          return _json({
            'conversation_id': 'conversation-001',
            'runs': [_run()],
            'has_more': false,
          });
        }
        if (httpRequest.method == 'GET' &&
            httpRequest.url.path.endsWith('/timeline')) {
          return _json({
            'conversation_id': 'conversation-001',
            'run_id': 'run-001',
            'after_sequence': 0,
            'scanned_through_sequence': 0,
            'has_more': false,
            'events': <Object>[],
          });
        }
        if (httpRequest.method == 'POST' &&
            httpRequest.url.path.contains('attempt-lease-dispatch-preflight')) {
          candidateRequests.add(httpRequest);
          throw StateError('Hidden client instance must block preflight POST.');
        }
        throw StateError(
          'Unexpected Forge request: ${httpRequest.method} ${httpRequest.url}',
        );
      });
      addTearDown(client.close);
      addTearDown(credentialStore.clear);

      await tester.pumpWidget(
        MaterialApp(
          home: ForgeSessionsGate(
            credentialStore: credentialStore,
            httpClient: client,
            initialConversationID: 'conversation-001',
            initialClientInstanceID: 'client-cli-001',
            clientInstanceSessionResourceConvergenceOwner: _owner,
            clientInstanceSessionResourceConvergenceReader: (_) async {
              pairReads++;
              return _clientInstancePair(hidden: pairReads > 1);
            },
            runAttemptLeaseDispatchPreflightRequest: request,
            enableRunAttemptLeaseDispatchPreflightCandidate: true,
            runAttemptLeaseDispatchPreflightCandidateApiOrigin:
                'https://candidate.example',
          ),
        ),
      );
      await _settle(tester);

      expect(pairReads, greaterThan(1));
      expect(candidateRequests, isEmpty);
    },
  );
}

ForgeClientInstanceSessionResourceConvergence _clientInstancePair({
  bool hidden = false,
}) {
  final source = File(
    'docs/contracts/fixtures/forge-client-instance-session-resource-convergence-v1.json',
  ).readAsStringSync();
  final decoded = jsonDecode(source);
  if (!hidden) {
    return ForgeClientInstanceSessionResourceConvergence.fromJson(decoded);
  }
  final mutable = jsonDecode(jsonEncode(decoded)) as Map<String, dynamic>;
  for (final viewKey in const ['session_view', 'resource_view']) {
    final view = mutable[viewKey] as Map<String, dynamic>;
    final instances = (view['instances'] as List)
        .map((value) => Map<String, dynamic>.from(value as Map))
        .toList(growable: false);
    final selected = instances.singleWhere(
      (value) => value['instance_id'] == 'client-cli-001',
    );
    selected['session_ids'] = ['conversation-002'];
    view['instances'] = instances;
  }
  return ForgeClientInstanceSessionResourceConvergence.fromJson(mutable);
}

Future<ForgeCredentialStore> _credentialStore(String token) async {
  final store = ForgeCredentialStore(
    backend: MemoryForgeCredentialBackend(),
    forcePersistentStorage: true,
  );
  expect(await store.store(accessToken: token), isTrue);
  return store;
}

Future<void> _settle(WidgetTester tester) async {
  for (var index = 0; index < 10; index++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump();
  }
  await tester.pumpAndSettle();
}

Map<String, dynamic> _conversation() => {
  'conversation': {
    'id': 'conversation-001',
    'scope': {'kind': 'global'},
    'title': 'Shared work',
    'created_at_ms': 1,
    'updated_at_ms': 2,
  },
  'aggregate_version': 1,
};

Map<String, dynamic> _run() => {
  'run_id': 'run-001',
  'prompt_id': 'prompt-001',
  'created_at_ms': 10,
  'latest_sequence': 1,
  'status': 'nonterminal',
};

ForgeRunAttemptLeaseDispatchPreflightRequest _request() =>
    ForgeRunAttemptLeaseDispatchPreflightRequest.fromJson({
      'owner': _owner.toJson(),
      'conversation_id': 'conversation-001',
      'run_id': 'run-001',
      'run_status': 'nonterminal',
      'dispatch_plan': {
        'attempt_state': 'accepted',
        'placement_request': _placement(),
        'runner_execution_intent': _intent(),
        'lease': {
          'v': 1,
          'attempt_id': 'attempt-001',
          'target_id': 'runner-1',
          'epoch': 1,
          'fencing_token': 'fence-001',
          'issued_at_ms': 1799999999000,
          'expires_at_ms': 1800000005000,
        },
      },
    });

Map<String, dynamic> _intent() => {
  'schema_version': 'forge.runner-execution-intent/v1',
  'evaluation_mode': 'pure_runner_binding_only',
  'owner': _owner.toJson(),
  'conversation_id': 'conversation-001',
  'prompt_id': 'prompt-001',
  'run_id': 'run-001',
  'attempt_id': 'attempt-001',
  'command_id': 'command-001',
  'target_id': 'runner-1',
  'command_sha256':
      'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
  'idempotency_key': 'run-001:attempt-001:command-001',
  'prompt_run_binding_valid': true,
  'runner_command_binding_valid': true,
  'preview_only': true,
  'selected_target_id': null,
  'authority': {
    'device_identity_verified': false,
    'command_persisted': false,
    'reservation_created': false,
    'execution_authorized': false,
    'dispatch_performed': false,
    'audit_published': false,
  },
};

Map<String, dynamic> _placement() => {
  'schema_version': 'forge.device-placement-dry-run/v1',
  'evaluated_at_ms': 1800000000000,
  'owner': _owner.toJson(),
  'max_snapshot_age_ms': 60000,
  'requirements': {
    'os': 'linux',
    'architecture': 'amd64',
    'min_cpu_cores': 1,
    'min_memory_bytes': 1024,
    'min_storage_bytes': 1024,
    'runtime': 'oci',
    'gpu': {'required': false, 'min_memory_bytes': 0, 'runtime': ''},
    'data_residency_zones': ['us-west'],
    'minimum_trust_zone': 'standard',
    'sandbox_floor': 'container',
    'concurrency_slots': 1,
  },
  'devices': [_device('runner-1')],
};

Map<String, dynamic> _device(String id) => {
  'device_id': id,
  'owner': _owner.toJson(),
  'approval_state': 'approved',
  'cordon_state': 'clear',
  'liveness': 'online',
  'snapshot_observed_at_ms': 1799999999000,
  'lease_expires_at_ms': 1800000060000,
  'os': 'linux',
  'architecture': 'amd64',
  'available_cpu_cores': 4,
  'available_memory_bytes': 8192,
  'available_storage_bytes': 65536,
  'runtimes': ['oci'],
  'gpu': {'present': false, 'memory_bytes': 0, 'runtime': ''},
  'data_residency_zones': ['us-west'],
  'trust_zone': 'standard',
  'sandbox_levels': ['container'],
  'concurrency_limit': 4,
  'active_concurrency': 0,
};

Map<String, dynamic> _response() => {
  'schema_version': 'forge.run-attempt-lease-dispatch-preflight/v1',
  'evaluation_mode': 'pure_run_attempt_lease_dispatch_preflight',
  'owner': _owner.toJson(),
  'conversation_id': 'conversation-001',
  'run_id': 'run-001',
  'run_status': 'nonterminal',
  'run_state_admissible': true,
  'attempt_id': 'attempt-001',
  'attempt_state': 'accepted',
  'attempt_state_admissible': true,
  'command_id': 'command-001',
  'intent_target_id': 'runner-1',
  'lease_epoch': 1,
  'lease_active': true,
  'evaluated_at_ms': 1800000000000,
  'candidate_count': 1,
  'declarative_ready_count': 1,
  'declarative_preflight_ready': true,
  'rejection_reasons': <String>[],
  'selected_target_id': null,
  'preview_only': true,
  'authority': {
    'identity_verified': false,
    'run_authoritative': false,
    'attempt_persisted': false,
    'lease_issued': false,
    'reservation_created': false,
    'execution_authorized': false,
    'dispatch_performed': false,
    'audit_published': false,
  },
};
