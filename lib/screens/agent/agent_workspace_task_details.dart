import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sso_admin/api/agent_compute_models.dart';
import 'package:sso_admin/api/agent_hub_api.dart';
import 'package:sso_admin/i18n/app_strings.dart';
import 'package:sso_admin/services/agent_workspace_file.dart';

class AgentWorkspaceTaskDetails extends StatefulWidget {
  final AgentHubApi api;
  final AgentComputeTask task;
  final VoidCallback onSignIn;

  const AgentWorkspaceTaskDetails({
    super.key,
    required this.api,
    required this.task,
    required this.onSignIn,
  });

  @override
  State<AgentWorkspaceTaskDetails> createState() =>
      _AgentWorkspaceTaskDetailsState();
}

class _AgentWorkspaceTaskDetailsState extends State<AgentWorkspaceTaskDetails> {
  bool _busy = false;
  bool _scopeMissing = false;
  String? _error;
  int _generation = 0;
  String? _notice;
  AgentWorkspaceFileSupport _fileSupport = const AgentWorkspaceFileSupport();

  @override
  void initState() {
    super.initState();
    _loadFileSupport();
  }

  Future<void> _loadFileSupport() async {
    final support = await agentWorkspaceFileSupport();
    if (mounted) setState(() => _fileSupport = support);
  }

  Object _version(AgentComputeTask task) => (
    task.taskId,
    task.sessionId,
    task.workspaceResult?.state,
    task.workspaceResult?.inputSha256,
    task.workspaceResult?.outputSha256,
  );

  @override
  void didUpdateWidget(covariant AgentWorkspaceTaskDetails oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_version(oldWidget.task) != _version(widget.task) ||
        oldWidget.api != widget.api) {
      _generation++;
      _busy = false;
      _error = null;
      _scopeMissing = false;
      _notice = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final result = widget.task.workspaceResult;
    if (result == null && widget.task.workspace == null) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 8),
        Text(
          context.tr('Workspace output'),
          style: Theme.of(context).textTheme.titleSmall,
        ),
        if (widget.task.workspace != null)
          Text(
            context.tr('Snapshot: {id}', {
              'id': widget.task.workspace!.snapshotId,
            }),
          ),
        if (result != null) ...[
          SelectableText(
            context.tr('Input SHA-256: {digest}', {
              'digest': result.inputSha256,
            }),
          ),
          if (result.outputSha256.isNotEmpty)
            SelectableText(
              context.tr('Output SHA-256: {digest}', {
                'digest': result.outputSha256,
              }),
            ),
        ],
        Text(
          context.tr('Workspace artifact: {state}', {
            'state': context.tr(switch (result?.state) {
              'ready' => 'Ready to download',
              'pending' => 'pending',
              'failed' => 'failed',
              _ => 'Unavailable or not reported',
            }),
          }),
        ),
        if (result?.state == 'ready')
          Wrap(
            spacing: 8,
            children: [
              TextButton.icon(
                onPressed: _busy ? null : () => _download(),
                icon: const Icon(Icons.download_outlined),
                label: Text(
                  context.tr(
                    kIsWeb
                        ? 'Download workspace JSON'
                        : _fileSupport.save
                        ? 'Save workspace JSON'
                        : 'View workspace JSON',
                  ),
                ),
              ),
              if (!kIsWeb && _fileSupport.save)
                TextButton(
                  onPressed: _busy ? null : () => _download(viewOnly: true),
                  child: Text(context.tr('View workspace JSON')),
                ),
            ],
          ),
        if (_busy) const LinearProgressIndicator(),
        if (_notice != null) Text(context.tr(_notice!)),
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
      ],
    );
  }

  Future<void> _download({bool viewOnly = false}) async {
    final generation = _generation;
    final task = widget.task;
    final expected = task.workspaceResult;
    if (expected == null) return;
    setState(() {
      _busy = true;
      _error = null;
      _notice = null;
      _scopeMissing = false;
    });
    try {
      final output = await widget.api.downloadWorkspace(
        taskId: task.taskId,
        expected: expected,
      );
      if (!mounted || generation != _generation) return;
      if (!viewOnly && (kIsWeb || _fileSupport.save)) {
        final saved = await saveAgentWorkspaceJson(
          output.bundle.canonicalJson,
          taskId: task.taskId,
        );
        if (!mounted || generation != _generation) return;
        setState(
          () => _notice = kIsWeb
              ? 'Workspace download requested.'
              : saved
              ? 'Workspace JSON saved.'
              : 'File save cancelled.',
        );
      } else {
        setState(() => _busy = false);
        await _showJson(output.bundle.canonicalJson);
      }
    } on Exception catch (error) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _scopeMissing =
            error is AgentHubApiException &&
            (error.isForbidden || error.isUnauthorized);
        _error = error is FormatException
            ? error.message
            : error is AgentHubApiException
            ? error.message
            : 'Could not download workspace output.';
      });
    } finally {
      if (mounted && generation == _generation) setState(() => _busy = false);
    }
  }

  Future<void> _showJson(String json) => showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(dialogContext.tr('Verified workspace JSON')),
      content: SizedBox(
        width: 640,
        child: SingleChildScrollView(child: SelectableText(json)),
      ),
      actions: [
        TextButton(
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: json));
            if (dialogContext.mounted) Navigator.of(dialogContext).pop();
          },
          child: Text(dialogContext.tr('Copy workspace JSON')),
        ),
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: Text(dialogContext.tr('Close')),
        ),
      ],
    ),
  );
}
