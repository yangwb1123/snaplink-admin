import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import 'agent_workspace_file_contract.dart';
import 'browser_download.dart';

Future<AgentWorkspaceFileSupport> support() async =>
    const AgentWorkspaceFileSupport(pick: true, save: true);

/// Checks the browser file size before reading and validates UTF-8.
Future<String?> pickJson({required int maxBytes}) async {
  validateWorkspaceFileLimit(maxBytes);
  final input = web.HTMLInputElement()
    ..type = 'file'
    ..accept = '.json,application/json'
    ..hidden = true.toJS;
  web.document.body?.append(input);
  final selected = Completer<web.File?>();
  final changed = ((web.Event event) {
    if (!selected.isCompleted) selected.complete(input.files?.item(0));
  }).toJS;
  final cancelled = ((web.Event event) {
    if (!selected.isCompleted) selected.complete(null);
  }).toJS;
  input.addEventListener('change', changed);
  input.addEventListener('cancel', cancelled);
  try {
    input.click();
    final file = await selected.future.timeout(const Duration(minutes: 2));
    if (file == null) return null;
    if (file.size > maxBytes) {
      throw const FormatException('Workspace JSON exceeds 512 KiB.');
    }
    final buffer = await file.arrayBuffer().toDart.timeout(
      const Duration(seconds: 30),
    );
    final bytes = buffer.toDart.asUint8List();
    if (bytes.length > maxBytes) {
      throw const FormatException('Workspace JSON exceeds 512 KiB.');
    }
    return utf8.decode(bytes, allowMalformed: false);
  } finally {
    input.removeEventListener('change', changed);
    input.removeEventListener('cancel', cancelled);
    input.remove();
  }
}

Future<bool> saveJson(Uint8List bytes, {required String filename}) async {
  BrowserDownload.bytes(
    bytes,
    filename: filename,
    contentType: 'application/json',
  );
  return true;
}
