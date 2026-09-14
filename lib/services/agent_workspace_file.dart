import 'dart:convert';
import 'dart:typed_data';

import 'agent_workspace_file_contract.dart';
import 'agent_workspace_file_stub.dart'
    if (dart.library.io) 'agent_workspace_file_native.dart'
    if (dart.library.js_interop) 'agent_workspace_file_web.dart'
    as platform;

export 'agent_workspace_file_contract.dart' show AgentWorkspaceFileSupport;

Future<AgentWorkspaceFileSupport> agentWorkspaceFileSupport() =>
    platform.support();

Future<String?> pickAgentWorkspaceJson({required int maxBytes}) =>
    platform.pickJson(maxBytes: maxBytes);

Future<bool> saveAgentWorkspaceJson(String content, {required String taskId}) {
  if (content.length > agentWorkspaceFileMaxBytes) {
    throw const FormatException('Workspace JSON exceeds 512 KiB.');
  }
  final bytes = Uint8List.fromList(utf8.encode(content));
  if (bytes.length > agentWorkspaceFileMaxBytes) {
    throw const FormatException('Workspace JSON exceeds 512 KiB.');
  }
  return platform.saveJson(bytes, filename: agentWorkspaceFilename(taskId));
}
