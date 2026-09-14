const agentWorkspaceFileMaxBytes = 512 * 1024;

class AgentWorkspaceFileSupport {
  final bool pick;
  final bool save;

  const AgentWorkspaceFileSupport({this.pick = false, this.save = false});
}

String agentWorkspaceFilename(String taskId) {
  var name = taskId.replaceAll(RegExp('[^A-Za-z0-9_-]'), '_');
  if (name.isEmpty) name = 'output';
  if (name.length > 96) name = name.substring(0, 96);
  return 'workspace-$name.json';
}

void validateWorkspaceFileLimit(int maxBytes) {
  if (maxBytes < 1 || maxBytes > agentWorkspaceFileMaxBytes) {
    throw const FormatException('Invalid workspace file size limit.');
  }
}
