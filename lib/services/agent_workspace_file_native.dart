import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';

import 'agent_workspace_file_contract.dart';

const _channel = MethodChannel('site.ywbsd.sso/agent_workspace_files');
bool _active = false;

Future<AgentWorkspaceFileSupport> support() async {
  try {
    final value = await _channel
        .invokeMethod<Object?>('capabilities')
        .timeout(const Duration(seconds: 5));
    if (value is Map && value['version'] == 1 && value['version'] is int) {
      return AgentWorkspaceFileSupport(
        pick: value['pick'] == true,
        save: value['save'] == true,
      );
    }
  } on MissingPluginException {
    return const AgentWorkspaceFileSupport();
  } on PlatformException {
    return const AgentWorkspaceFileSupport();
  } on TimeoutException {
    return const AgentWorkspaceFileSupport();
  }
  return const AgentWorkspaceFileSupport();
}

Future<Object?> _invoke(String method, Map<String, Object> arguments) async {
  if (_active) {
    throw const FormatException('Another file operation is already open.');
  }
  _active = true;
  try {
    return await _channel.invokeMethod<Object?>(method, arguments);
  } on MissingPluginException {
    throw const FormatException(
      'File access is unavailable. Use workspace JSON instead.',
    );
  } on PlatformException catch (error) {
    throw FormatException(switch (error.code) {
      'too_large' => 'Workspace JSON exceeds 512 KiB.',
      'busy' => 'Another file operation is already open.',
      'unavailable' =>
        'File access is unavailable. Use workspace JSON instead.',
      'invalid_arguments' => 'Invalid workspace file request.',
      _ => 'Could not access the selected workspace file.',
    });
  } finally {
    _active = false;
  }
}

Future<String?> pickJson({required int maxBytes}) async {
  validateWorkspaceFileLimit(maxBytes);
  final value = await _invoke('pickJson', {'maxBytes': maxBytes});
  if (value == null) return null;
  if (value is! Uint8List) {
    throw const FormatException('Invalid workspace file response.');
  }
  if (value.length > maxBytes) {
    throw const FormatException('Workspace JSON exceeds 512 KiB.');
  }
  try {
    return utf8.decode(value, allowMalformed: false);
  } on FormatException {
    throw const FormatException('Workspace file must contain valid UTF-8.');
  }
}

Future<bool> saveJson(Uint8List bytes, {required String filename}) async {
  final value = await _invoke('saveJson', {
    'filename': filename,
    'bytes': bytes,
  });
  if (value is! bool) {
    throw const FormatException('Invalid workspace file response.');
  }
  return value;
}
