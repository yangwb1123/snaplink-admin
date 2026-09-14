import 'dart:typed_data';

import 'agent_workspace_file_contract.dart';

Future<AgentWorkspaceFileSupport> support() async =>
    const AgentWorkspaceFileSupport();

Future<String?> pickJson({required int maxBytes}) async =>
    throw const FormatException(
      'File access is unavailable. Use workspace JSON instead.',
    );

Future<bool> saveJson(Uint8List bytes, {required String filename}) async =>
    throw const FormatException(
      'File access is unavailable. Use workspace JSON instead.',
    );
