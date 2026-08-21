import 'package:flutter/material.dart';
import 'package:sso_admin/api/snaplink_admin_api.dart';
import 'package:sso_admin/i18n/app_strings.dart';
import 'package:sso_admin/i18n/localized_text.dart';
import 'package:sso_admin/widgets/admin_breadcrumb.dart';
import 'package:sso_admin/widgets/app_snackbar.dart';
import 'package:sso_admin/widgets/async_view.dart';
import 'package:sso_admin/widgets/confirm_dialog.dart';
import 'package:sso_admin/widgets/section_header.dart';
import 'package:sso_admin/widgets/pull_to_refresh.dart';
import 'package:sso_admin/widgets/skeleton_list.dart';

import 'admin_module_groups.dart';
import 'admin_navigation.dart';
import 'recovery_dialogs.dart';
import 'recovery_release_widgets.dart';

/// Snapshot, backup, and paired frontend/backend release lifecycle.
/// Mutations are durable (server-journaled under an operation id); a failed
/// or unknown write result is never replayed — reconcile first.
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
  static const _operationsPath = '/api/v1/admin/operations';

  List<Map<String, dynamic>> _snapshots = const [];
  List<Map<String, dynamic>> _releases = const [];
  List<Map<String, dynamic>> _operations = const [];
  Map<String, dynamic>? _currentRelease;
  Map<String, dynamic>? _drStatus;
  Map<String, dynamic>? _lastReport;
  String? _error;
  bool _loading = false;
  bool _mutating = false;

  /// 请求序号：恢复/发布数据由多个可选端点聚合，旧批次不得回写新批次。
  int _reqSeq = 0;
  final Set<String> _restorePreviews = {};

  /// 模块组色（developers → emerald）：页头图标统一上色（X7）。
  Color get _accent => adminModuleIconColor(AdminModuleId.recoveryReleases);

  bool _has(String method, String path) =>
      widget.capabilities.has(method, path) ||
      SnaplinkAdminOperationCatalog.endpoints.any(
        (endpoint) => endpoint.method == method && endpoint.path == path,
      );

  Future<(String, Map<String, dynamic>?, String?)> _readSection(
    String key,
    String path,
    int seq,
  ) async {
    try {
      return (
        key,
        await widget.api.getStaleWhileRevalidate(
          path,
          onRefresh: (fresh) {
            if (mounted && seq == _reqSeq) {
              setState(() => _applySection(key, fresh));
            }
          },
        ),
        null,
      );
    } on SnaplinkAdminApiError catch (error) {
      final state = error.status == 404 || error.status == 501
          ? 'not enabled on this replica'
          : 'failed to load (${error.status})';
      return (key, null, '$key: $state');
    } catch (_) {
      return (key, null, '$key: failed to load');
    }
  }

  /// 缓存先渲染：命中时立即展示缓存行，后台刷新到位后原位更新（R2）。
  void _applySection(String key, Map<String, dynamic> data) {
    switch (key) {
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
      case 'Operations':
        _operations = recoveryRecords(data['operations']);
        break;
    }
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final seq = ++_reqSeq;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final jobs = <Future<(String, Map<String, dynamic>?, String?)>>[
        if (_has('GET', _snapshotsPath))
          _readSection('Snapshots', _snapshotsPath, seq),
        if (_has('GET', _releasesPath))
          _readSection('Releases', _releasesPath, seq),
        if (_has('GET', '$_releasesPath:current'))
          _readSection('Current release', '$_releasesPath:current', seq),
        if (_has('GET', '/api/v1/admin/dr/status'))
          _readSection('DR status', '/api/v1/admin/dr/status', seq),
        if (_has('GET', _operationsPath))
          _readSection('Operations', _operationsPath, seq),
      ];
      final results = await Future.wait(jobs);
      if (!mounted || seq != _reqSeq) return;
      setState(() {
        final errors = <String>[];
        for (final result in results) {
          if (result.$3 != null) {
            errors.add(result.$3!);
            continue;
          }
          final data = result.$2!;
          _applySection(result.$1, data);
        }
        _error = errors.isEmpty ? null : errors.join('\n');
      });
    } finally {
      if (mounted && seq == _reqSeq) setState(() => _loading = false);
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
              'Run a successful dry-run preview with these exact restore settings before committing.',
        );
        return;
      }
      final confirmed = await _confirm(
        'Restore snapshot?',
        context.tr(
          'Apply {mode} restore from {id}? Resource families are applied sequentially. Snaplink records every step and final result in a durable operation journal for reconciliation.',
          {'mode': draft.mode, 'id': id},
        ),
        confirmLabel: 'Restore snapshot',
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
          context.tr('Delete stored snapshot {id}?', {'id': id}),
          confirmLabel: 'Delete snapshot',
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
      'pin' => context.tr('Pin {id} as the current paired release?', {
        'id': id,
      }),
      'rollback' =>
        context.tr('Rollback frontend and backend to {id}? {warning}', {
          'id': id,
          'warning': context.tr(
            'Snapshot restore, traffic pinning, registry updates, and compensations are recorded in a durable operation journal.',
          ),
        }),
      _ => context.tr('Delete registered release {id}?', {'id': id}),
    };
    final confirmLabel = switch (action) {
      'pin' => 'Pin release',
      'rollback' => 'Rollback',
      _ => 'Delete release',
    };
    if (!await _confirm(
      action == 'pin'
          ? 'Pin release?'
          : action == 'rollback'
          ? 'Rollback release?'
          : 'Delete release?',
      message,
      confirmLabel: confirmLabel,
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
      confirmLabel: 'Create backup',
      confirmText: 'CREATE BACKUP',
    )) {
      return;
    }
    await _write(
      () => widget.api.post('/api/v1/admin/backup', {}),
      'Online backup completed.',
    );
  }

  Future<bool> _confirm(
    String title,
    String message, {
    String confirmLabel = 'Continue',
    String? confirmText,
  }) => ConfirmDialog.show(
    context,
    title: title,
    message: message,
    confirmLabel: confirmLabel,
    destructive: true,
    confirmText: confirmText,
  );

  /// Durable write: surface the journaled operation id/state from the report,
  /// then reload. A failed or unknown result is never replayed — the journal
  /// is refreshed and the operator reconciles before retrying.
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
      final operationId = report['operation_id']?.toString();
      final operationState =
          recoveryRecord(report['operation'])?['state']?.toString() ??
          'recorded';
      final tracked = operationId != null && operationId.isNotEmpty;
      showAppSnackBar(
        context,
        content: tracked
            ? LocalizedText(
                '{message} Operation {operationId} is {operationState}.',
                args: {
                  'message': context.tr(success),
                  'operationId': operationId,
                  'operationState': operationState,
                },
              )
            : LocalizedText(success),
      );
      await _load();
      return true;
    } on SnaplinkAdminApiError catch (error) {
      await _reconcileFailedWrite(
        error.toString(),
        operationId: error.operationId,
      );
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

  Future<void> _reconcileFailedWrite(
    String message, {
    String? operationId,
  }) async {
    if (!mounted) return;
    await _load();
    if (!mounted) return;
    final sectionError = _error;
    setState(
      () => _error =
          '$message ${operationId == null ? '' : 'Operation $operationId failed. '}The durable operation journal and visible state were refreshed; inspect every failed step and compensation before retrying.${sectionError == null ? '' : '\n$sectionError'}',
    );
  }

  @override
  Widget build(BuildContext context) => PullToRefresh(
    onRefresh: _load,
    child: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const AdminBreadcrumb(),
        _header(context),
        if (_error != null) ...[const SizedBox(height: 4), _errorCard(context)],
        if (_loading) ...[
          const SizedBox(height: 12),
          const SkeletonListTile(itemCount: 3),
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
        const SizedBox(height: 12),
        RecoveryOperationsCard(operations: _operations),
        if (_lastReport?.isNotEmpty == true) ...[
          const SizedBox(height: 12),
          _reportCard(context),
        ],
      ],
    ),
  );

  /// 页头：图标按模块组色上色（X7）；标题/副标题走 i18n 字面量。
  Widget _header(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.restore_outlined, color: _accent, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(
                  container: true,
                  header: true,
                  child: Text(
                    context.tr('Recovery and releases'),
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.3,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  context.tr(
                    'Manage encrypted state snapshots and coordinated frontend/backend release pins.',
                  ),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              IconButton(
                onPressed: _loading || _mutating ? null : _load,
                icon: const Icon(Icons.refresh),
                tooltip: 'Refresh'.localized,
              ),
              if (_has('POST', '/api/v1/admin/backup'))
                FilledButton.icon(
                  onPressed: _mutating ? null : _backup,
                  icon: const Icon(Icons.backup_outlined),
                  label: const LocalizedText('Online backup'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  /// 错误区：统一 ErrorStateCard（图标 + 明细 + Retry）。Retry 只重放安全
  /// 读取（GET）——不会重放上次写入，结果未知不重放的语义保持不变。
  Widget _errorCard(BuildContext context) => ErrorStateCard(
    message: _error ?? '',
    onRetry: _load,
    retryEnabled: !_loading,
  );

  Widget _reportCard(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader('Last operation report'),
          const SizedBox(height: 8),
          SelectableText(_lastReport.toString()),
        ],
      ),
    ),
  );
}
