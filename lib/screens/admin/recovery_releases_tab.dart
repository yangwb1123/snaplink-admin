import 'package:flutter/material.dart';
import 'package:sso_admin/api/snaplink_admin_api.dart';
import 'package:sso_admin/widgets/admin_breadcrumb.dart';
import 'package:sso_admin/widgets/confirm_dialog.dart';

import 'recovery_dialogs.dart';
import 'recovery_release_widgets.dart';

/// Snapshot, backup, and paired frontend/backend release lifecycle.
class RecoveryReleasesTab extends StatefulWidget {
  final SnaplinkAdminApi api;
  final SnaplinkAdminCapabilities capabilities;

  const RecoveryReleasesTab({
    super.key,
    required this.api,
    required this.capabilities,
  });

  @override
  State<RecoveryReleasesTab> createState() => _RecoveryReleasesTabState();
}

class _RecoveryReleasesTabState extends State<RecoveryReleasesTab> {
  static const _snapshotsPath = '/api/v1/admin/snapshots';
  static const _releasesPath = '/api/v1/admin/releases';

  List<Map<String, dynamic>> _snapshots = const [];
  List<Map<String, dynamic>> _releases = const [];
  Map<String, dynamic>? _currentRelease;
  Map<String, dynamic>? _drStatus;
  Map<String, dynamic>? _lastReport;
  String? _error;
  bool _loading = false;
  bool _mutating = false;
  final Set<String> _restorePreviews = {};

  bool _has(String method, String path) =>
      widget.capabilities.has(method, path) ||
      SnaplinkAdminOperationCatalog.endpoints.any(
        (endpoint) => endpoint.method == method && endpoint.path == path,
      );

  Future<(String, Map<String, dynamic>?, String?)> _readSection(
    String key,
    String path,
  ) async {
    try {
      return (key, await widget.api.get(path, forceRefresh: true), null);
    } on SnaplinkAdminApiError catch (error) {
      final state = error.status == 404 || error.status == 501
          ? 'not enabled on this replica'
          : 'failed to load (${error.status})';
      return (key, null, '$key: $state');
    } catch (_) {
      return (key, null, '$key: failed to load');
    }
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final jobs = <Future<(String, Map<String, dynamic>?, String?)>>[
        if (_has('GET', _snapshotsPath))
          _readSection('Snapshots', _snapshotsPath),
        if (_has('GET', _releasesPath)) _readSection('Releases', _releasesPath),
        if (_has('GET', '$_releasesPath:current'))
          _readSection('Current release', '$_releasesPath:current'),
        if (_has('GET', '/api/v1/admin/dr/status'))
          _readSection('DR status', '/api/v1/admin/dr/status'),
      ];
      final results = await Future.wait(jobs);
      if (!mounted) return;
      setState(() {
        final errors = <String>[];
        for (final result in results) {
          if (result.$3 != null) {
            errors.add(result.$3!);
            continue;
          }
          final data = result.$2!;
          switch (result.$1) {
            case 'Snapshots':
              _snapshots = recoveryRecords(data['items']);
              break;
            case 'Releases':
              _releases = recoveryRecords(data['items']);
              break;
            case 'Current release':
              _currentRelease = recoveryRecord(data['release']);
              break;
            case 'DR status':
              _drStatus = data;
              break;
          }
        }
        _error = errors.isEmpty ? null : errors.join('\n');
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _createSnapshot() async {
    await _write(
      () => widget.api.post(_snapshotsPath, {'exclude': <String>[]}),
      'Snapshot exported.',
    );
  }

  Future<void> _restore(Map<String, dynamic> snapshot) async {
    final id = snapshot['snapshot_id']?.toString() ?? '';
    if (id.isEmpty) return;
    final draft = await showDialog<SnapshotRestoreDraft>(
      context: context,
      builder: (_) => SnapshotRestoreDialog(snapshotId: id),
    );
    if (draft == null || !mounted) return;
    final previewKey = draft.previewKey(id);
    if (!draft.dryRun) {
      if (!_restorePreviews.contains(previewKey)) {
        setState(
          () => _error =
              'Run a successful dry-run preview with these exact restore '
              'settings before committing.',
        );
        return;
      }
      final confirmed = await ConfirmDialog.show(
        context,
        title: 'Restore snapshot?',
        message:
            'Apply ${draft.mode} restore from $id? Snaplink currently applies '
            'resource families sequentially rather than transactionally. A '
            'failure can leave partial changes, so verify the operation '
            'report and reconcile every affected resource afterward.',
        confirmLabel: 'Restore',
        destructive: true,
        confirmText: id,
      );
      if (!confirmed) return;
    }
    final succeeded = await _write(
      () => widget.api.post(
        '$_snapshotsPath/${Uri.encodeComponent(id)}:restore',
        draft.toJson(id),
      ),
      draft.dryRun ? 'Restore preview complete.' : 'Snapshot restored.',
    );
    if (succeeded) {
      if (draft.dryRun) {
        _restorePreviews.add(previewKey);
      } else {
        _restorePreviews.remove(previewKey);
      }
    }
  }

  Future<void> _deleteSnapshot(Map<String, dynamic> snapshot) async {
    final id = snapshot['snapshot_id']?.toString() ?? '';
    if (id.isEmpty ||
        !await _confirm(
          'Delete snapshot?',
          'Delete stored snapshot $id?',
          confirmText: id,
        )) {
      return;
    }
    await _write(
      () => widget.api.delete('$_snapshotsPath/${Uri.encodeComponent(id)}'),
      'Snapshot deleted.',
    );
  }

  Future<void> _registerRelease() async {
    final draft = await showDialog<ReleaseDraft>(
      context: context,
      builder: (_) => const ReleaseDialog(),
    );
    if (draft == null || !mounted) return;
    await _write(
      () => widget.api.post(_releasesPath, draft.toJson()),
      'Release registered.',
    );
  }

  Future<void> _releaseAction(
    Map<String, dynamic> release,
    String action,
  ) async {
    final id = release['id']?.toString() ?? '';
    if (id.isEmpty) return;
    final message = switch (action) {
      'pin' => 'Pin $id as the current paired release?',
      'rollback' =>
        'Rollback frontend and backend to $id? Snapshot restore, traffic '
            'pinning, and registry updates are not atomic. A failure may '
            'leave a partially changed release state.',
      _ => 'Delete registered release $id?',
    };
    if (!await _confirm(
      '${action[0].toUpperCase()}${action.substring(1)} release?',
      message,
      confirmText: id,
    )) {
      return;
    }
    await _write(
      () => action == 'delete'
          ? widget.api.delete('$_releasesPath/${Uri.encodeComponent(id)}')
          : widget.api.post(
              '$_releasesPath/${Uri.encodeComponent(id)}:$action',
              {},
            ),
      'Release action completed.',
    );
  }

  Future<void> _backup() async {
    if (!await _confirm(
      'Create online backup?',
      'Trigger a consistent online backup of every registered SQLite source?',
      confirmText: 'CREATE BACKUP',
    )) {
      return;
    }
    await _write(
      () => widget.api.post('/api/v1/admin/backup', {}),
      'Online backup completed.',
    );
  }

  Future<bool> _confirm(String title, String message, {String? confirmText}) =>
      ConfirmDialog.show(
        context,
        title: title,
        message: message,
        confirmLabel: 'Continue',
        destructive: true,
        confirmText: confirmText,
      );

  Future<bool> _write(
    Future<Map<String, dynamic>> Function() operation,
    String success,
  ) async {
    setState(() {
      _mutating = true;
      _error = null;
    });
    try {
      final report = await operation();
      if (!mounted) return false;
      setState(() => _lastReport = report);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(success)));
      await _load();
      return true;
    } on SnaplinkAdminApiError catch (error) {
      await _reconcileFailedWrite(error.toString());
      return false;
    } catch (_) {
      await _reconcileFailedWrite(
        'The write result is unknown because Snaplink could not be reached.',
      );
      return false;
    } finally {
      if (mounted) setState(() => _mutating = false);
    }
  }

  Future<void> _reconcileFailedWrite(String message) async {
    if (!mounted) return;
    await _load();
    if (!mounted) return;
    final sectionError = _error;
    setState(
      () => _error =
          '$message The operation may have partially applied; visible state '
          'was refreshed and external health/storage must be verified.'
          '${sectionError == null ? '' : '\n$sectionError'}',
    );
  }

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      const AdminBreadcrumb(),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            'Recovery and releases',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          IconButton(
            onPressed: _loading || _mutating ? null : _load,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
          if (_has('POST', '/api/v1/admin/backup'))
            FilledButton.icon(
              onPressed: _mutating ? null : _backup,
              icon: const Icon(Icons.backup_outlined),
              label: const Text('Online backup'),
            ),
        ],
      ),
      const SizedBox(height: 4),
      const Text(
        'Manage encrypted state snapshots and coordinated frontend/backend release pins.',
      ),
      if (_error != null) ...[
        const SizedBox(height: 8),
        Text(_error!, style: const TextStyle(color: Colors.redAccent)),
      ],
      if (_loading) ...[
        const SizedBox(height: 12),
        const LinearProgressIndicator(),
      ],
      const SizedBox(height: 12),
      if (_drStatus != null) RecoveryStatusCard(status: _drStatus!),
      const SizedBox(height: 12),
      RecoverySnapshotsCard(
        snapshots: _snapshots,
        canCreate: _has('POST', _snapshotsPath),
        mutating: _mutating,
        onCreate: _createSnapshot,
        onRestore: _restore,
        onDelete: _deleteSnapshot,
      ),
      const SizedBox(height: 12),
      RecoveryReleasesCard(
        releases: _releases,
        current: _currentRelease,
        canRegister: _has('POST', _releasesPath),
        mutating: _mutating,
        onRegister: _registerRelease,
        onAction: _releaseAction,
      ),
      if (_lastReport?.isNotEmpty == true) ...[
        const SizedBox(height: 12),
        Card(
          child: ListTile(
            leading: const Icon(Icons.task_alt),
            title: const Text('Last operation report'),
            subtitle: SelectableText(_lastReport.toString()),
          ),
        ),
      ],
    ],
  );
}
