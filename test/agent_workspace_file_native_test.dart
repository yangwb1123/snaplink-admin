@TestOn('vm')
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sso_admin/services/agent_workspace_file.dart';

const _channel = MethodChannel('site.ywbsd.sso/agent_workspace_files');

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  void host(Future<Object?> Function(MethodCall)? handle) =>
      binding.defaultBinaryMessenger.setMockMethodCallHandler(_channel, handle);
  tearDown(() => host(null));

  test(
    'capabilities require the supported version and explicit booleans',
    () async {
      for (final response in [
        null,
        {},
        {'version': 2, 'pick': true},
        {'version': 1.0, 'pick': true},
        {'version': 1, 'pick': 1, 'save': 'true'},
      ]) {
        host((_) async => response);
        final result = await agentWorkspaceFileSupport();
        expect(result.pick, isFalse);
        expect(result.save, isFalse);
      }
      host((_) async => {'version': 1, 'pick': true, 'save': false});
      final result = await agentWorkspaceFileSupport();
      expect(result.pick, isTrue);
      expect(result.save, isFalse);
    },
  );

  test('missing host keeps JSON fallback available', () async {
    final support = await agentWorkspaceFileSupport();
    expect(support.pick, isFalse);
    expect(support.save, isFalse);
    await expectLater(
      pickAgentWorkspaceJson(maxBytes: 10),
      throwsFormatException,
    );
  });

  test('picker returns exact UTF-8 and validates the declared limit', () async {
    host((call) async {
      expect(call.method, 'pickJson');
      expect(call.arguments, {'maxBytes': 16});
      return Uint8List.fromList(utf8.encode('é\u0000日本'));
    });
    expect(await pickAgentWorkspaceJson(maxBytes: 16), 'é\u0000日本');
    await expectLater(
      pickAgentWorkspaceJson(maxBytes: 0),
      throwsFormatException,
    );
    await expectLater(
      pickAgentWorkspaceJson(maxBytes: 524289),
      throwsFormatException,
    );
  });

  test('picker cancellation is distinct from empty bytes', () async {
    host((_) async => null);
    expect(await pickAgentWorkspaceJson(maxBytes: 20), isNull);
    host((_) async => Uint8List(0));
    expect(await pickAgentWorkspaceJson(maxBytes: 20), '');
  });

  test(
    'untrusted host cannot return oversize, wrong type or invalid UTF-8',
    () async {
      for (final response in [
        Uint8List(21),
        <int>[65],
        'text',
        Uint8List.fromList([255]),
      ]) {
        host((_) async => response);
        await expectLater(
          pickAgentWorkspaceJson(maxBytes: 20),
          throwsFormatException,
        );
      }
    },
  );

  test('save enforces UTF-8 size before opening the host dialog', () async {
    var calls = 0;
    host((_) async {
      calls++;
      return true;
    });
    expect(
      () => saveAgentWorkspaceJson('x' * 524289, taskId: 't'),
      throwsFormatException,
    );
    expect(
      () => saveAgentWorkspaceJson('é' * 262145, taskId: 't'),
      throwsFormatException,
    );
    expect(calls, 0);
    expect(await saveAgentWorkspaceJson('x' * 524288, taskId: 't'), isTrue);
    expect(calls, 1);
  });

  test('save passes verified bytes with a bounded portable filename', () async {
    host((call) async {
      final args = call.arguments as Map;
      expect(call.method, 'saveJson');
      expect(args['bytes'], utf8.encode('é\u0000'));
      expect(
        args['filename'],
        matches(r'^workspace-[A-Za-z0-9_-]{1,96}\.json$'),
      );
      return true;
    });
    for (final id in ['../CON:\\path\n', 'x' * 200, '']) {
      expect(await saveAgentWorkspaceJson('é\u0000', taskId: id), isTrue);
    }
  });

  test(
    'save distinguishes cancellation and rejects malformed acknowledgements',
    () async {
      host((_) async => false);
      expect(await saveAgentWorkspaceJson('{}', taskId: 't'), isFalse);
      for (final response in [
        null,
        1,
        'saved',
        {'saved': true},
      ]) {
        host((_) async => response);
        await expectLater(
          saveAgentWorkspaceJson('{}', taskId: 't'),
          throwsFormatException,
        );
      }
    },
  );

  test(
    'parallel dialogs are blocked until the outstanding host reply',
    () async {
      final pending = Completer<Object?>();
      host((_) => pending.future);
      final first = pickAgentWorkspaceJson(maxBytes: 20);
      await expectLater(
        saveAgentWorkspaceJson('{}', taskId: 't'),
        throwsFormatException,
      );
      pending.complete(null);
      expect(await first, isNull);
      host((_) async => true);
      expect(await saveAgentWorkspaceJson('{}', taskId: 't'), isTrue);
    },
  );

  test(
    'host failure releases operation and never leaks provider detail',
    () async {
      host(
        (_) async => throw PlatformException(
          code: 'io_error',
          message: '/private/selected.json',
        ),
      );
      await expectLater(
        pickAgentWorkspaceJson(maxBytes: 20),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            'Could not access the selected workspace file.',
          ),
        ),
      );
      host((_) async => Uint8List.fromList([65]));
      expect(await pickAgentWorkspaceJson(maxBytes: 20), 'A');
    },
  );
}
