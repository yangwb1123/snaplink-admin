import 'package:sso_admin/api/agent_workspace_models.dart';

class AgentWorkspaceSelection {
  final bool enabled;
  final AgentWorkspaceSnapshot? snapshot;
  final String outputsText;

  const AgentWorkspaceSelection({
    this.enabled = false,
    this.snapshot,
    this.outputsText = '',
  });

  AgentWorkspaceRequest? toRequest() {
    if (!enabled) return null;
    return AgentWorkspaceRequest(
      snapshotId: snapshot?.snapshotId ?? '',
      outputs: outputsText
          .split(RegExp(r'\r?\n'))
          .where((path) => path.isNotEmpty)
          .toList(),
    );
  }
}
