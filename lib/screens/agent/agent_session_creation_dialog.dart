import 'package:flutter/material.dart';
import 'package:sso_admin/api/agent_hub_models.dart';
import 'package:sso_admin/api/agent_session_creation_models.dart';
import 'package:sso_admin/i18n/app_strings.dart';
import 'agent_session_creation.dart';

class AgentSessionCreationDialog extends StatefulWidget {
  final AgentSessionCreation creation;
  final List<AgentInstance> instances;
  final String initialInstance;
  final VoidCallback onSubmit;
  final VoidCallback onOpen;

  const AgentSessionCreationDialog({
    super.key,
    required this.creation,
    required this.instances,
    required this.initialInstance,
    required this.onSubmit,
    required this.onOpen,
  });

  @override
  State<AgentSessionCreationDialog> createState() => _CreationDialogState();
}

class _CreationDialogState extends State<AgentSessionCreationDialog> {
  late final TextEditingController _name;
  late String _target;
  String? _validation;

  AgentSessionCreation get creation => widget.creation;
  List<AgentInstance> get targets => widget.instances
      .where((instance) => instance.online && instance.sessionCapacity > 0)
      .toList();

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: creation.name);
    _target = creation.hasInput ? creation.instanceId : widget.initialInstance;
    if (!creation.hasInput &&
        !targets.any((item) => item.instanceId == _target)) {
      _target = '';
    }
    creation.addListener(_changed);
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    creation.removeListener(_changed);
    _name.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    try {
      validateAgentSessionName(_name.text);
    } on FormatException {
      setState(
        () => _validation =
            'Enter a session name of at most 256 UTF-8 bytes without control characters.',
      );
      return;
    }
    if (_target.isEmpty) return;
    setState(() => _validation = null);
    if (!creation.hasInput) widget.onSubmit();
    await creation.submit(_target, _name.text);
  }

  @override
  Widget build(BuildContext context) {
    final current = creation.request;
    return AlertDialog(
      title: Text(context.tr('New session')),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (creation.hasInput) ...[
                Text(creation.name),
                Text(creation.instanceId),
              ] else
                ..._fields(context),
              if (current != null) ...[
                const SizedBox(height: 16),
                Text(context.tr(creationStatus(current))),
              ],
              if (creation.busy) ...[
                const SizedBox(height: 16),
                const LinearProgressIndicator(),
              ],
              if (creation.error != null) ...[
                const SizedBox(height: 16),
                Text(context.tr(creation.error!)),
              ],
              const SizedBox(height: 16),
              Text(
                context.tr(
                  'The instance uses its configured project and model. Closing this dialog keeps tracking until you leave Agent Operations.',
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(context.tr('Close')),
        ),
        if (current?.status == 'created')
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              widget.onOpen();
            },
            child: Text(context.tr('Open session')),
          ),
        if (creation.canReset)
          TextButton(
            onPressed: () {
              creation.reset();
              setState(() {
                _target = '';
                _name.clear();
              });
            },
            child: Text(context.tr('Start another session')),
          ),
        if (creation.queued && creation.error != null)
          FilledButton(
            onPressed: creation.busy ? null : creation.refresh,
            child: Text(context.tr('Retry status')),
          ),
        if (current == null)
          FilledButton(
            onPressed: creation.busy || _target.isEmpty ? null : _submit,
            child: Text(
              context.tr(
                creation.hasInput ? 'Retry same request' : 'Create session',
              ),
            ),
          ),
      ],
    );
  }

  List<Widget> _fields(BuildContext context) => [
    if (targets.isEmpty)
      Text(context.tr('No online instance supports remote session creation.')),
    DropdownButtonFormField<String>(
      key: const ValueKey('new-session-instance'),
      initialValue: _target.isEmpty ? null : _target,
      isExpanded: true,
      decoration: InputDecoration(labelText: context.tr('Target instance')),
      items: targets
          .map(
            (instance) => DropdownMenuItem(
              value: instance.instanceId,
              child: Text(
                instance.name.isEmpty ? instance.instanceId : instance.name,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          )
          .toList(),
      onChanged: creation.busy
          ? null
          : (value) => setState(() => _target = value ?? ''),
    ),
    const SizedBox(height: 16),
    TextField(
      key: const ValueKey('new-session-name'),
      controller: _name,
      enabled: !creation.busy,
      decoration: InputDecoration(
        labelText: context.tr('Session name'),
        errorText: _validation == null ? null : context.tr(_validation!),
      ),
      onSubmitted: (_) => _submit(),
    ),
  ];
}
