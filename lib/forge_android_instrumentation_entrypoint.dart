import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import 'screens/forge/forge_sessions_gate.dart';
import 'screens/forge/forge_sessions_screen.dart';
import 'services/forge_change_cursor_store.dart';
import 'services/forge_conversations_oauth.dart';
import 'services/forge_credential_store.dart';
import 'api/forge_conversations_api.dart';
import 'api/forge_client_instance_resource_view.dart';
import 'api/forge_client_instance_session_resource_convergence.dart';
import 'api/forge_client_instance_session_view.dart';

/// Debug/instrumentation entrypoint used by the Android Activity lifecycle
/// harness. It runs the real [ForgeSessionsGate] and [ForgeSessionsScreen]
/// against a bounded in-process HTTP fixture, while the Gate restores its
/// bearer from the real Android secure-storage plugin.
///
/// This entrypoint is intentionally never selected by the product router. The
/// Android runner starts it only in a debug APK with an explicitly selected
/// disposable emulator. The fixture has no write or device route, so a green
/// instrumentation result cannot be mistaken for production execution.
@pragma('vm:entry-point')
Future<void> forgeAndroidInstrumentationMain() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    MaterialApp(
      home: ForgeSessionsGate(
        credentialStore: ForgeCredentialStore(),
        testScreenBuilder: (accessToken) => ForgeSessionsScreen(
          accessToken: accessToken,
          apiOrigin: 'http://forge-instrumentation.invalid',
          httpClient: _ForgeAndroidInstrumentationClient(
            accessToken: accessToken,
          ),
        ),
      ),
    ),
  );
}

/// Debug-only entrypoint for an explicitly configured Android emulator.
///
/// Unlike [forgeAndroidInstrumentationMain], this path does not use an
/// in-process HTTP fixture. The native test supplies only a private
/// configuration filename; the bearer is restored from the real Android
/// secure-storage plugin and the API origin points at a caller-selected
/// Forge Coordinator. The entrypoint performs one bounded read/write/replay
/// probe and reports metadata back through the debug channel. It is never
/// selected by the product router and does not expose any device route.
@pragma('vm:entry-point')
Future<void> forgeAndroidCoordinatorInstrumentationMain() async {
  WidgetsFlutterBinding.ensureInitialized();
  Object? error;
  Map<String, Object?>? report;
  try {
    final configuration = await const MethodChannel(
      'site.ywbsd.sso/forge_instrumentation',
    ).invokeMethod<Map<Object?, Object?>>('configuration');
    final config = _coordinatorConfiguration(configuration);
    final accessToken = await ForgeCredentialStore().restore();
    if (accessToken == null || accessToken.isEmpty) {
      throw const FormatException('Forge credential was not restored.');
    }

    final cursorStore = ForgeChangeCursorStore(
      accessToken: accessToken,
      apiOrigin: config.apiURL,
      clientId: ForgeConversationsOAuth.clientId,
      resource: ForgeConversationsOAuth.resource,
    );
    var restoredCursor = await cursorStore.load();
    if (restoredCursor == 0 && config.afterCursor > 0) {
      if (!await cursorStore.save(config.afterCursor)) {
        throw StateError('Forge cursor seed did not persist.');
      }
      restoredCursor = await cursorStore.load();
    }

    final api = ForgeConversationsApi(
      baseUrl: config.apiURL,
      accessToken: accessToken,
      httpClient: _ForgeAndroidCoordinatorClient(),
    );
    try {
      final expectedPair = config.expectedPair;
      final observedPair = await api.readConvergedClientInstanceViews(
        owner: expectedPair.owner,
      );
      _assertCoordinatorInstancePair(
        observedPair,
        expectedPair: expectedPair,
        clientInstanceID: config.clientInstanceID,
        conversationID: config.conversationID,
      );
      final conversations = await api.listConversations(limit: 50);
      final conversation = conversations.conversations.singleWhere(
        (entry) => entry.conversation.id == config.conversationID,
      );
      if (conversation.aggregateVersion < config.expectedVersion) {
        throw StateError('Forge Conversation version moved backwards.');
      }
      final baseline = await api.conversationChanges(
        afterCursor: restoredCursor,
        limit: 128,
      );
      if (baseline.afterCursor != restoredCursor) {
        throw StateError('Forge change cursor binding drifted.');
      }
      if (!await cursorStore.save(baseline.scannedThroughCursor)) {
        throw StateError('Forge baseline cursor did not persist.');
      }
      await api.listPrompts(conversationID: config.conversationID, limit: 100);
      final appended = await api.appendPrompt(
        conversationID: config.conversationID,
        content: config.prompt,
        expectedVersion: config.expectedVersion,
        idempotencyKey: config.idempotencyKey,
      );
      final replayed = await api.appendPrompt(
        conversationID: config.conversationID,
        content: config.prompt,
        expectedVersion: config.expectedVersion,
        idempotencyKey: config.idempotencyKey,
      );
      if (appended.prompt.id != replayed.prompt.id ||
          replayed.prompt.content != config.prompt ||
          replayed.aggregateVersion != appended.aggregateVersion ||
          !replayed.replayed) {
        throw StateError('Forge Prompt idempotency replay drifted.');
      }
      final changes = await api.conversationChanges(
        afterCursor: await cursorStore.load(),
        limit: 128,
      );
      if (!await cursorStore.save(changes.scannedThroughCursor)) {
        throw StateError('Forge final cursor did not persist.');
      }
      report = <String, Object?>{
        'run_index': config.runIndex,
        'restored_cursor': restoredCursor,
        'final_cursor': changes.scannedThroughCursor,
        'aggregate_version': replayed.aggregateVersion,
        'prompt_id': replayed.prompt.id,
        'replayed': replayed.replayed,
      };
    } finally {
      api.close();
    }
  } catch (caught) {
    error = caught.toString();
  }
  await _recordCoordinatorCompletion(report: report, error: error);
  runApp(
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: Text(
            error == null
                ? 'Forge coordinator probe complete'
                : 'Forge coordinator probe failed',
          ),
        ),
      ),
    ),
  );
}

final class _ForgeAndroidCoordinatorClient extends http.BaseClient {
  final http.Client _inner = http.Client();

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    String? authorization;
    for (final entry in request.headers.entries) {
      if (entry.key.toLowerCase() == 'authorization') {
        authorization = entry.value;
        break;
      }
    }
    await _recordRequest(
      path: request.url.path,
      authorized: authorization?.startsWith('Bearer ') == true,
    );
    return _inner.send(request);
  }

  @override
  void close() {
    _inner.close();
  }
}

final class _CoordinatorConfiguration {
  final String apiURL;
  final String conversationID;
  final String clientInstanceID;
  final ForgeClientInstanceSessionResourceConvergence expectedPair;
  final int expectedVersion;
  final int afterCursor;
  final String prompt;
  final String idempotencyKey;
  final int runIndex;

  const _CoordinatorConfiguration({
    required this.apiURL,
    required this.conversationID,
    required this.clientInstanceID,
    required this.expectedPair,
    required this.expectedVersion,
    required this.afterCursor,
    required this.prompt,
    required this.idempotencyKey,
    required this.runIndex,
  });
}

_CoordinatorConfiguration _coordinatorConfiguration(
  Map<Object?, Object?>? raw,
) {
  if (raw == null) {
    throw const FormatException('Missing coordinator configuration.');
  }
  if (raw.keys.any((key) => key is! String)) {
    throw const FormatException(
      'Coordinator configuration keys must be strings.',
    );
  }
  final value = <String, Object?>{
    for (final entry in raw.entries)
      if (entry.key is String) entry.key as String: entry.value,
  };
  const expected = <String>{
    'api_url',
    'conversation_id',
    'client_instance_id',
    'session_view',
    'resource_view',
    'expected_version',
    'after_cursor',
    'prompt',
    'idempotency_key',
    'run_index',
  };
  if (value.length != expected.length ||
      !value.keys.toSet().containsAll(expected)) {
    throw const FormatException('Unexpected coordinator configuration fields.');
  }
  final apiURL = value['api_url'];
  final conversationID = value['conversation_id'];
  final clientInstanceID = value['client_instance_id'];
  final sessionView = _decodeCoordinatorView(
    value['session_view'],
    resource: false,
  );
  final resourceView = _decodeCoordinatorView(
    value['resource_view'],
    resource: true,
  );
  final expectedVersion = value['expected_version'];
  final afterCursor = value['after_cursor'];
  final prompt = value['prompt'];
  final idempotencyKey = value['idempotency_key'];
  final runIndex = value['run_index'];
  if (apiURL is! String ||
      conversationID is! String ||
      clientInstanceID is! String ||
      prompt is! String ||
      idempotencyKey is! String ||
      expectedVersion is! int ||
      afterCursor is! int ||
      runIndex is! int ||
      apiURL.isEmpty ||
      conversationID.isEmpty ||
      clientInstanceID.isEmpty ||
      prompt.isEmpty ||
      idempotencyKey.isEmpty ||
      expectedVersion < 1 ||
      afterCursor < 0 ||
      runIndex < 1 ||
      runIndex > 2) {
    throw const FormatException('Invalid coordinator configuration.');
  }
  final expectedPair = ForgeClientInstanceSessionResourceConvergence.fromJson({
    'schema_version': forgeClientInstanceSessionResourceConvergenceSchema,
    'evaluation_mode':
        forgeClientInstanceSessionResourceConvergenceEvaluationMode,
    'session_view': sessionView,
    'resource_view': resourceView,
    'converged': true,
    'read_only': true,
    'authority':
        const ForgeClientInstanceSessionResourceConvergenceAuthority.offline()
            .toJson(),
  });
  _assertCoordinatorInstancePair(
    expectedPair,
    expectedPair: expectedPair,
    clientInstanceID: clientInstanceID,
    conversationID: conversationID,
  );
  return _CoordinatorConfiguration(
    apiURL: apiURL,
    conversationID: conversationID,
    clientInstanceID: clientInstanceID,
    expectedPair: expectedPair,
    expectedVersion: expectedVersion,
    afterCursor: afterCursor,
    prompt: prompt,
    idempotencyKey: idempotencyKey,
    runIndex: runIndex,
  );
}

Map<String, dynamic> _decodeCoordinatorView(
  Object? raw, {
  required bool resource,
}) {
  Object? value = raw;
  if (value is String) {
    try {
      value = jsonDecode(value);
    } catch (_) {
      throw const FormatException(
        'Invalid coordinator client-instance view JSON.',
      );
    }
  }
  if (value is! Map) {
    throw const FormatException(
      'Coordinator client-instance view must be an object.',
    );
  }
  return resource
      ? ForgeClientInstanceResourceView.fromJson(value).toJson()
      : ForgeClientInstanceSessionView.fromJson(value).toJson();
}

void _assertCoordinatorInstancePair(
  ForgeClientInstanceSessionResourceConvergence observed, {
  required ForgeClientInstanceSessionResourceConvergence expectedPair,
  required String clientInstanceID,
  required String conversationID,
}) {
  if (!observed.isDisplayOnly ||
      jsonEncode(observed.sessionView.toJson()) !=
          jsonEncode(expectedPair.sessionView.toJson()) ||
      jsonEncode(observed.resourceView.toJson()) !=
          jsonEncode(expectedPair.resourceView.toJson())) {
    throw const FormatException(
      'Coordinator client-instance session/resource observations drifted.',
    );
  }
  final selected = observed.sessionView.instances
      .where((instance) => instance.instanceID == clientInstanceID)
      .toList(growable: false);
  if (selected.length != 1 ||
      selected.single.clientKind != 'mobile' ||
      !selected.single.sessionIDs.contains(conversationID)) {
    throw const FormatException(
      'Coordinator Conversation is hidden from the selected mobile instance.',
    );
  }
}

Future<void> _recordCoordinatorCompletion({
  required Map<String, Object?>? report,
  required Object? error,
}) async {
  try {
    await const MethodChannel(
      'site.ywbsd.sso/forge_instrumentation',
    ).invokeMethod<void>('complete', <String, Object?>{
      'ok': error == null,
      'report': report == null ? null : jsonEncode(report),
      'error': error?.toString(),
    });
  } catch (_) {
    // The completion marker is observability only; API failures remain in the
    // native test's bounded timeout and never change product behavior.
  }
}

final class _ForgeAndroidInstrumentationClient extends http.BaseClient {
  _ForgeAndroidInstrumentationClient({required this.accessToken});

  final String accessToken;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    String? authorization;
    for (final entry in request.headers.entries) {
      if (entry.key.toLowerCase() == 'authorization') {
        authorization = entry.value;
        break;
      }
    }
    final authorized = authorization == 'Bearer $accessToken';
    await _recordRequest(path: request.url.path, authorized: authorized);
    if (!authorized) {
      return _response(request, 401, {'error': 'unauthorized'});
    }

    final path = request.url.path;
    if (request.method == 'GET' && path == '/api/v1/conversations') {
      return _response(request, 200, {
        'conversations': [
          {
            'conversation': {
              'id': 'android-shared-conversation',
              'scope': {'kind': 'global'},
              'title': 'Android lifecycle shared session',
              'created_at_ms': 10,
              'updated_at_ms': 20,
            },
            'aggregate_version': 1,
          },
        ],
        'has_more': false,
      });
    }
    if (request.method == 'GET' &&
        path == '/api/v1/conversations/android-shared-conversation/prompts') {
      return _response(request, 200, {
        'conversation_id': 'android-shared-conversation',
        'prompts': [
          {
            'id': 'android-prompt-1',
            'conversation_id': 'android-shared-conversation',
            'role': 'user',
            'content': 'Prompt restored after Activity recreation',
            'created_at_ms': 30,
          },
        ],
        'has_more': false,
      });
    }
    if (request.method == 'GET' &&
        path == '/api/v1/conversations/android-shared-conversation/runs') {
      return _response(request, 200, {
        'conversation_id': 'android-shared-conversation',
        'runs': <Object>[],
        'has_more': false,
      });
    }
    if (request.method == 'GET' && path == '/api/v1/conversation-changes') {
      final cursor =
          int.tryParse(request.url.queryParameters['after_cursor'] ?? '') ?? 0;
      return _response(request, 200, {
        'after_cursor': cursor,
        'scanned_through_cursor': cursor,
        'has_more': false,
        'changes': <Object>[],
      });
    }
    return _response(request, 404, {'error': 'not_found'});
  }

  http.StreamedResponse _response(
    http.BaseRequest request,
    int status,
    Object body,
  ) {
    final bytes = utf8.encode(jsonEncode(body));
    return http.StreamedResponse(
      Stream<List<int>>.value(bytes),
      status,
      request: request,
      headers: const {'content-type': 'application/json'},
    );
  }
}

Future<void> _recordRequest({
  required String path,
  required bool authorized,
}) async {
  try {
    await const MethodChannel(
      'site.ywbsd.sso/forge_instrumentation',
    ).invokeMethod<void>('request', {'path': path, 'authorized': authorized});
  } catch (_) {
    // Instrumentation markers are observability only. The fixture must remain
    // runnable when someone invokes this entrypoint outside the Android test.
  }
}
