part of '../forge_android_instrumentation_entrypoint.dart';

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
