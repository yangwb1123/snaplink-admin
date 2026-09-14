import 'package:flutter/material.dart';
import 'package:sso_admin/api/agent_hub_api.dart';
import 'package:sso_admin/api/agent_idempotency_key.dart';
import 'package:sso_admin/api/agent_workspace_models.dart';
import 'package:sso_admin/i18n/app_strings.dart';
import 'package:sso_admin/services/agent_workspace_file.dart';
import 'agent_workspace_selection.dart';

part 'agent_workspace_form_actions.dart';

class AgentWorkspaceForm extends StatefulWidget {
  final AgentHubApi api;
  final Map<String, String>? idempotencyKeys;
  final String sessionId;
  final String instanceId;
  final String projectId;
  final AgentWorkspaceSelection value;
  final bool disabled;
  final ValueChanged<AgentWorkspaceSelection> onChanged;
  final VoidCallback onSignIn;

  const AgentWorkspaceForm({
    super.key,
    required this.api,
    this.idempotencyKeys,
    required this.sessionId,
    required this.instanceId,
    required this.projectId,
    required this.value,
    required this.disabled,
    required this.onChanged,
    required this.onSignIn,
  });

  @override
  State<AgentWorkspaceForm> createState() => _AgentWorkspaceFormState();
}

class _AgentWorkspaceFormState extends State<AgentWorkspaceForm> {
  final _json = TextEditingController();
  late final TextEditingController _outputs;
  final Map<String, String> _localKeys = {};
  Map<String, String> get _keys => widget.idempotencyKeys ?? _localKeys;
  List<AgentWorkspaceSnapshot> _snapshots = [];
  String? _cursor;
  String? _error;
  bool _scopeMissing = false;
  bool _busy = false;
  int _generation = 0;
  AgentWorkspaceFileSupport _fileSupport = const AgentWorkspaceFileSupport();

  @override
  void initState() {
    super.initState();
    _outputs = TextEditingController(text: widget.value.outputsText);
    _loadFileSupport();
  }

  Future<void> _loadFileSupport() async {
    final support = await agentWorkspaceFileSupport();
    if (mounted) setState(() => _fileSupport = support);
  }

  @override
  void didUpdateWidget(covariant AgentWorkspaceForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sessionId != widget.sessionId ||
        oldWidget.api != widget.api ||
        oldWidget.instanceId != widget.instanceId ||
        oldWidget.projectId != widget.projectId) {
      _generation++;
      _snapshots = [];
      _cursor = null;
      _busy = false;
      _error = null;
      _scopeMissing = false;
      _json.clear();
      _outputs.text = widget.value.outputsText;
    }
  }

  @override
  void dispose() {
    _json.dispose();
    _outputs.dispose();
    super.dispose();
  }

  void _change({
    bool? enabled,
    AgentWorkspaceSnapshot? snapshot,
    bool clear = false,
  }) {
    widget.onChanged(
      AgentWorkspaceSelection(
        enabled: enabled ?? widget.value.enabled,
        snapshot: clear ? null : snapshot ?? widget.value.snapshot,
        outputsText: _outputs.text,
      ),
    );
  }

  void _update(VoidCallback change) => setState(change);

  @override
  Widget build(BuildContext context) {
    final selected = widget.value.snapshot;
    final choices = {
      for (final snapshot in _snapshots) snapshot.snapshotId: snapshot,
    };
    if (selected != null) choices[selected.snapshotId] = selected;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          title: Text(context.tr('Use a workspace snapshot')),
          value: widget.value.enabled,
          onChanged: widget.disabled
              ? null
              : (value) {
                  _generation++;
                  setState(() {
                    _busy = false;
                    _error = null;
                  });
                  _change(enabled: value);
                  if (value) _load();
                },
        ),
        if (widget.value.enabled) ...[
          Text(
            context.tr(
              'Tasks run at the snapshot root (.). Results are exported as a JSON bundle.',
            ),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            key: ValueKey(selected?.snapshotId),
            initialValue: selected?.snapshotId,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: context.tr('Workspace snapshot'),
              border: const OutlineInputBorder(),
            ),
            items: [
              for (final snapshot in choices.values)
                DropdownMenuItem(
                  value: snapshot.snapshotId,
                  child: Text(
                    '${snapshot.snapshotId} · ${snapshot.fileCount}',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: widget.disabled || _busy
                ? null
                : (id) => _change(snapshot: choices[id]),
          ),
          if (selected != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: SelectableText(
                context.tr('Input SHA-256: {digest}', {
                  'digest': selected.sha256,
                }),
              ),
            ),
          Wrap(
            spacing: 8,
            children: [
              TextButton.icon(
                onPressed: _busy ? null : () => _load(),
                icon: const Icon(Icons.refresh),
                label: Text(context.tr('Refresh snapshots')),
              ),
              if (_cursor != null)
                TextButton(
                  onPressed: _busy ? null : () => _load(more: true),
                  child: Text(context.tr('Load more snapshots')),
                ),
            ],
          ),
          TextField(
            controller: _json,
            enabled: !widget.disabled && !_busy,
            minLines: 3,
            maxLines: 5,
            decoration: InputDecoration(
              labelText: context.tr('Workspace bundle JSON'),
              hintText: '{"schema":"pbatch.workspace.v1","files":[]}',
              helperText: context.tr(
                'Up to 128 files, 64 KiB each, 256 KiB total; JSON up to 512 KiB.',
              ),
              helperMaxLines: 4,
              border: const OutlineInputBorder(),
            ),
          ),
          Wrap(
            spacing: 8,
            children: [
              if (_fileSupport.pick)
                TextButton.icon(
                  onPressed: widget.disabled || _busy ? null : _pick,
                  icon: const Icon(Icons.file_open_outlined),
                  label: Text(context.tr('Choose JSON file')),
                ),
              TextButton.icon(
                onPressed: widget.disabled || _busy ? null : _upload,
                icon: const Icon(Icons.cloud_upload_outlined),
                label: Text(context.tr('Upload snapshot')),
              ),
            ],
          ),
          TextField(
            controller: _outputs,
            enabled: !widget.disabled && !_busy,
            minLines: 2,
            maxLines: 4,
            onChanged: (_) => _change(),
            decoration: InputDecoration(
              labelText: context.tr('Output file paths'),
              helperText: context.tr(
                'One explicit relative file path per line, up to 128. No wildcards.',
              ),
              helperMaxLines: 4,
              border: const OutlineInputBorder(),
            ),
          ),
          if (_busy) const LinearProgressIndicator(),
          if (_error != null)
            Text(
              context.tr(_error!),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          if (_scopeMissing)
            TextButton(
              onPressed: widget.onSignIn,
              child: Text(context.tr('Sign in for Agent access')),
            ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}
