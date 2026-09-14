@TestOn('browser')
library;

import 'dart:js_interop';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:web/web.dart' as web;
import 'package:sso_admin/services/agent_workspace_file.dart';

web.HTMLInputElement _input() =>
    web.document.querySelector('input[type=file]')! as web.HTMLInputElement;
void _choose(List<int> bytes) {
  final file = web.File(
    [Uint8List.fromList(bytes).toJS].toJS,
    'workspace.json',
  );
  final transfer = web.DataTransfer();
  transfer.items.add(file);
  final input = _input()..files = transfer.files;
  input.dispatchEvent(web.Event('change'));
}

void main() {
  test('browser picker reads bounded UTF8 and removes its input', () async {
    final result = pickAgentWorkspaceJson(maxBytes: 16);
    _choose([123, 125]);
    expect(await result, '{}');
    expect(web.document.querySelector('input[type=file]'), isNull);
  });
  test(
    'browser picker rejects oversized files before accepting contents',
    () async {
      final result = pickAgentWorkspaceJson(maxBytes: 2);
      _choose([1, 2, 3]);
      await expectLater(result, throwsFormatException);
      expect(web.document.querySelector('input[type=file]'), isNull);
    },
  );
  test(
    'browser picker rejects malformed UTF8 without replacement decoding',
    () async {
      final result = pickAgentWorkspaceJson(maxBytes: 16);
      _choose([255]);
      await expectLater(result, throwsFormatException);
      expect(web.document.querySelector('input[type=file]'), isNull);
    },
  );
  test('browser picker cancellation has no upload and removes input', () async {
    final result = pickAgentWorkspaceJson(maxBytes: 16);
    _input().dispatchEvent(web.Event('cancel'));
    expect(await result, isNull);
    expect(web.document.querySelector('input[type=file]'), isNull);
  });
}
