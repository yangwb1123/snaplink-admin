import 'package:flutter/material.dart';

class SnapshotRestoreDraft {
  final String mode;
  final bool dryRun;
  final bool advanceBootstrap;
  final List<String> exclude;

  const SnapshotRestoreDraft({
    required this.mode,
    required this.dryRun,
    required this.advanceBootstrap,
    required this.exclude,
  });

  Map<String, dynamic> toJson(String snapshotId) => {
    'mode': mode,
    'dry_run': dryRun,
    'advance_bootstrap': advanceBootstrap,
    'exclude': exclude,
    if (mode == 'replace') 'confirm': snapshotId,
  };

  String previewKey(String snapshotId) {
    final normalizedExclude = [...exclude]..sort();
    return '$snapshotId|$mode|$advanceBootstrap|${normalizedExclude.join(',')}';
  }
}

class SnapshotRestoreDialog extends StatefulWidget {
  final String snapshotId;

  const SnapshotRestoreDialog({super.key, required this.snapshotId});

  @override
  State<SnapshotRestoreDialog> createState() => _SnapshotRestoreDialogState();
}

class _SnapshotRestoreDialogState extends State<SnapshotRestoreDialog> {
  final _excludeCtrl = TextEditingController();
  String _mode = 'merge';
  bool _dryRun = true;
  bool _advanceBootstrap = false;

  @override
  void dispose() {
    _excludeCtrl.dispose();
    super.dispose();
  }

  List<String> _split(String value) => value
      .split(RegExp(r'[,\n]'))
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toList(growable: false);

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text('Restore snapshot ${widget.snapshotId}'),
    content: SizedBox(
      width: 520,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DropdownButtonFormField<String>(
            initialValue: _mode,
            decoration: const InputDecoration(labelText: 'Restore mode'),
            items: const [
              DropdownMenuItem(
                value: 'merge',
                child: Text('Merge — insert missing records only'),
              ),
              DropdownMenuItem(
                value: 'overwrite',
                child: Text('Overwrite — upsert snapshot records'),
              ),
              DropdownMenuItem(
                value: 'replace',
                child: Text('Replace — wipe and seed managed state'),
              ),
            ],
            onChanged: (value) => setState(() => _mode = value!),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _excludeCtrl,
            decoration: const InputDecoration(
              labelText: 'Excluded resource categories',
              helperText: 'Optional, one per line.',
            ),
            minLines: 2,
            maxLines: 4,
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Dry run'),
            subtitle: const Text('Calculate changes without persisting them.'),
            value: _dryRun,
            onChanged: (value) => setState(() => _dryRun = value),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Advance bootstrap high-water mark'),
            value: _advanceBootstrap,
            onChanged: (value) => setState(() => _advanceBootstrap = value),
          ),
          if (_mode == 'replace')
            const Text(
              'Replace mode removes operator-managed state before seeding the snapshot. The server requires the snapshot ID as confirmation.',
              style: TextStyle(color: Colors.redAccent),
            ),
          if (!_dryRun)
            const Text(
              'A successful dry run with the same snapshot, mode, exclusions, '
              'and bootstrap setting is required before commit.',
              style: TextStyle(color: Colors.orangeAccent),
            ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(
          context,
          SnapshotRestoreDraft(
            mode: _mode,
            dryRun: _dryRun,
            advanceBootstrap: _advanceBootstrap,
            exclude: _split(_excludeCtrl.text),
          ),
        ),
        child: Text(_dryRun ? 'Run preview' : 'Restore'),
      ),
    ],
  );
}

class ReleaseDraft {
  final String channel;
  final String frontendGitRef;
  final String frontendUri;
  final String backendGitRef;
  final String backendUri;
  final int schemaVersion;
  final String configSnapshot;
  final String notes;

  const ReleaseDraft({
    required this.channel,
    required this.frontendGitRef,
    required this.frontendUri,
    required this.backendGitRef,
    required this.backendUri,
    required this.schemaVersion,
    required this.configSnapshot,
    required this.notes,
  });

  Map<String, dynamic> toJson() => {
    'release': {
      'channel': channel,
      'frontend': {
        if (frontendGitRef.isNotEmpty) 'git_ref': frontendGitRef,
        if (frontendUri.isNotEmpty) 'uri': frontendUri,
      },
      'backend': {
        if (backendGitRef.isNotEmpty) 'git_ref': backendGitRef,
        if (backendUri.isNotEmpty) 'uri': backendUri,
      },
      'schema_version': schemaVersion,
      if (configSnapshot.isNotEmpty) 'config_snapshot': configSnapshot,
      if (notes.isNotEmpty) 'notes': notes,
    },
  };
}

class ReleaseDialog extends StatefulWidget {
  const ReleaseDialog({super.key});

  @override
  State<ReleaseDialog> createState() => _ReleaseDialogState();
}

class _ReleaseDialogState extends State<ReleaseDialog> {
  final _formKey = GlobalKey<FormState>();
  final _channelCtrl = TextEditingController(text: 'stable');
  final _frontendRefCtrl = TextEditingController();
  final _frontendUriCtrl = TextEditingController();
  final _backendRefCtrl = TextEditingController();
  final _backendUriCtrl = TextEditingController();
  final _schemaCtrl = TextEditingController(text: '0');
  final _snapshotCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  @override
  void dispose() {
    _channelCtrl.dispose();
    _frontendRefCtrl.dispose();
    _frontendUriCtrl.dispose();
    _backendRefCtrl.dispose();
    _backendUriCtrl.dispose();
    _schemaCtrl.dispose();
    _snapshotCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  bool _hasArtifact(String ref, String uri) =>
      ref.trim().isNotEmpty || uri.trim().isNotEmpty;

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(
      context,
      ReleaseDraft(
        channel: _channelCtrl.text.trim(),
        frontendGitRef: _frontendRefCtrl.text.trim(),
        frontendUri: _frontendUriCtrl.text.trim(),
        backendGitRef: _backendRefCtrl.text.trim(),
        backendUri: _backendUriCtrl.text.trim(),
        schemaVersion: int.parse(_schemaCtrl.text.trim()),
        configSnapshot: _snapshotCtrl.text.trim(),
        notes: _notesCtrl.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Register paired release'),
    content: SizedBox(
      width: 620,
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _channelCtrl,
                decoration: const InputDecoration(labelText: 'Channel'),
                validator: (value) =>
                    value?.trim().isEmpty == true ? 'Required' : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _frontendRefCtrl,
                decoration: const InputDecoration(
                  labelText: 'Frontend Git reference',
                ),
                validator: (_) =>
                    _hasArtifact(_frontendRefCtrl.text, _frontendUriCtrl.text)
                    ? null
                    : 'Set a frontend Git reference or URI',
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _frontendUriCtrl,
                decoration: const InputDecoration(
                  labelText: 'Frontend artifact URI',
                ),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _backendRefCtrl,
                decoration: const InputDecoration(
                  labelText: 'Backend Git reference',
                ),
                validator: (_) =>
                    _hasArtifact(_backendRefCtrl.text, _backendUriCtrl.text)
                    ? null
                    : 'Set a backend Git reference or URI',
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _backendUriCtrl,
                decoration: const InputDecoration(
                  labelText: 'Backend artifact URI',
                ),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _schemaCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Schema version'),
                validator: (value) => int.tryParse(value?.trim() ?? '') == null
                    ? 'Enter an integer'
                    : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _snapshotCtrl,
                decoration: const InputDecoration(
                  labelText: 'Config snapshot ID (optional)',
                ),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _notesCtrl,
                decoration: const InputDecoration(labelText: 'Release notes'),
                maxLines: 3,
              ),
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(onPressed: _submit, child: const Text('Register')),
    ],
  );
}
