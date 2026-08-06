import 'package:flutter/material.dart';
import 'package:sso_admin/theme/app_colors.dart';
import 'package:sso_admin/i18n/localized_text.dart';

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
    title: LocalizedText('Restore snapshot ${widget.snapshotId}'),
    content: SizedBox(
      width: 520,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DropdownButtonFormField<String>(
            initialValue: _mode,
            isExpanded: true,
            decoration: InputDecoration(labelText: 'Restore mode'.localized),
            items: const [
              DropdownMenuItem(
                value: 'merge',
                child: LocalizedText('Merge — insert missing records only'),
              ),
              DropdownMenuItem(
                value: 'overwrite',
                child: LocalizedText('Overwrite — upsert snapshot records'),
              ),
              DropdownMenuItem(
                value: 'replace',
                child: LocalizedText('Replace — wipe and seed managed state'),
              ),
            ],
            onChanged: (value) => setState(() => _mode = value!),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _excludeCtrl,
            decoration: InputDecoration(
              labelText: 'Excluded resource categories'.localized,
              helperText: 'Optional, one per line.'.localized,
            ),
            minLines: 2,
            maxLines: 4,
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const LocalizedText('Dry run'),
            subtitle: const LocalizedText(
              'Calculate changes without persisting them.',
            ),
            value: _dryRun,
            onChanged: (value) => setState(() => _dryRun = value),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const LocalizedText('Advance bootstrap high-water mark'),
            value: _advanceBootstrap,
            onChanged: (value) => setState(() => _advanceBootstrap = value),
          ),
          if (_mode == 'replace')
            const LocalizedText(
              'Replace mode removes operator-managed state before seeding the snapshot. The server requires the snapshot ID as confirmation.',
              style: TextStyle(color: AppColors.danger),
            ),
          if (!_dryRun)
            const LocalizedText(
              'A successful dry run with the same snapshot, mode, exclusions, '
              'and bootstrap setting is required before commit.',
              style: TextStyle(color: AppColors.warning),
            ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const LocalizedText('Cancel'),
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
        child: LocalizedText(_dryRun ? 'Run preview' : 'Restore'),
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
    title: const LocalizedText('Register paired release'),
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
                decoration: InputDecoration(labelText: 'Channel'.localized),
                validator: (value) =>
                    value?.trim().isEmpty == true ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _frontendRefCtrl,
                decoration: InputDecoration(
                  labelText: 'Frontend Git reference'.localized,
                ),
                validator: (_) =>
                    _hasArtifact(_frontendRefCtrl.text, _frontendUriCtrl.text)
                    ? null
                    : 'Set a frontend Git reference or URI',
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _frontendUriCtrl,
                decoration: InputDecoration(
                  labelText: 'Frontend artifact URI'.localized,
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _backendRefCtrl,
                decoration: InputDecoration(
                  labelText: 'Backend Git reference'.localized,
                ),
                validator: (_) =>
                    _hasArtifact(_backendRefCtrl.text, _backendUriCtrl.text)
                    ? null
                    : 'Set a backend Git reference or URI',
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _backendUriCtrl,
                decoration: InputDecoration(
                  labelText: 'Backend artifact URI'.localized,
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _schemaCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Schema version'.localized,
                ),
                validator: (value) => int.tryParse(value?.trim() ?? '') == null
                    ? 'Enter an integer'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _snapshotCtrl,
                decoration: InputDecoration(
                  labelText: 'Config snapshot ID (optional)'.localized,
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _notesCtrl,
                decoration: InputDecoration(
                  labelText: 'Release notes'.localized,
                ),
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
        child: const LocalizedText('Cancel'),
      ),
      FilledButton(onPressed: _submit, child: const LocalizedText('Register')),
    ],
  );
}
