import 'package:sso_admin/api/agent_workspace_models.dart';

AgentWorkspaceBundle workspaceBundle() => AgentWorkspaceBundle.fromJson({
  'schema': AgentWorkspaceBundle.schema,
  'files': [
    {'path': 'z/é.txt', 'content_b64': 'AAE='},
    {'path': 'a.txt', 'content_b64': 'YQ=='},
  ],
});

Map<String, dynamic> workspaceSnapshot({
  String session = 's-1',
  String id = 'snap-1',
}) {
  final bundle = workspaceBundle();
  return {
    'snapshot_id': id,
    'session_id': session,
    'instance_id': 'i-1',
    'project_id': 'project-1',
    'sha256': bundle.sha256,
    'size': bundle.size,
    'file_count': bundle.files.length,
    'created_at': 1789238400,
    'artifact_ref': {},
  };
}

Map<String, dynamic> workspaceResult({String state = 'ready'}) => {
  'input_sha256': workspaceBundle().sha256,
  'output_sha256': state == 'ready' ? workspaceBundle().sha256 : '',
  'state': state,
  'artifact_ref': {},
};

Map<String, dynamic> workspaceOutput() => {
  'input_sha256': workspaceBundle().sha256,
  'output_sha256': workspaceBundle().sha256,
  'bundle': workspaceBundle().toJson(),
};
