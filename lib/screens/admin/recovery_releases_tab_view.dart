part of 'recovery_releases_tab.dart';

extension _RecoveryReleasesTabView on _RecoveryReleasesTabState {
  Widget _buildRecoveryReleasesTab(BuildContext context) {
    final initialLoading =
        _loading &&
        _snapshots.isEmpty &&
        _releases.isEmpty &&
        _operations.isEmpty &&
        _currentRelease == null &&
        _drStatus == null &&
        _lastReport == null;
    return PullToRefresh(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const AdminBreadcrumb(),
          _header(context),
          if (_error != null) ...[
            const SizedBox(height: 4),
            _errorCard(context),
          ],
          if (initialLoading) ...[
            const SizedBox(height: 12),
            const SkeletonListTile(itemCount: 3),
          ],
          if (!initialLoading) ...[
            const SizedBox(height: 12),
            if (_drStatus != null) RecoveryStatusCard(status: _drStatus!),
            const SizedBox(height: 12),
            _recoveryCards(context),
            const SizedBox(height: 12),
            RecoveryOperationsCard(operations: _operations),
            if (_lastReport?.isNotEmpty == true) ...[
              const SizedBox(height: 12),
              _reportCard(context),
            ],
          ],
        ],
      ),
    );
  }

  /// At narrow widths, move card header actions above their cards. The shared
  /// SectionHeader keeps title/count and action in one row, which is too tight
  /// for these two long actions in the 320–432px range.
  Widget _recoveryCards(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final narrow = constraints.maxWidth < 640;
      final canCreate = _has('POST', _RecoveryReleasesTabState._snapshotsPath);
      final canRegister = _has('POST', _RecoveryReleasesTabState._releasesPath);
      final createAction = FilledButton.icon(
        onPressed: _mutating ? null : _createSnapshot,
        icon: const Icon(Icons.camera_outlined),
        label: const LocalizedText('Export snapshot'),
      );
      final registerAction = FilledButton.icon(
        onPressed: _mutating ? null : _registerRelease,
        icon: const Icon(Icons.add),
        label: const LocalizedText('Register release'),
      );
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (narrow && canCreate) ...[
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: createAction,
            ),
            const SizedBox(height: 8),
          ],
          RecoverySnapshotsCard(
            snapshots: _snapshots,
            canCreate: narrow ? false : canCreate,
            mutating: _mutating,
            onCreate: _createSnapshot,
            onRestore: _restore,
            onDelete: _deleteSnapshot,
          ),
          const SizedBox(height: 12),
          if (narrow && canRegister) ...[
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: registerAction,
            ),
            const SizedBox(height: 8),
          ],
          RecoveryReleasesCard(
            releases: _releases,
            current: _currentRelease,
            canRegister: narrow ? false : canRegister,
            mutating: _mutating,
            onRegister: _registerRelease,
            onAction: _releaseAction,
          ),
        ],
      );
    },
  );

  /// 页头：图标按模块组色上色（X7）；标题/副标题走 i18n 字面量。
  Widget _header(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 12),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final actions = Wrap(
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
          );
          final heading = Column(
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
          );
          final title = Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.restore_outlined, color: _accent, size: 28),
              const SizedBox(width: 12),
              Expanded(child: heading),
            ],
          );
          if (constraints.maxWidth < 640) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                title,
                const SizedBox(height: 8),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: actions,
                ),
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: title),
              const SizedBox(width: 12),
              actions,
            ],
          );
        },
      ),
    );
  }

  /// 错误区：统一 ErrorStateCard（图标 + 明细 + Retry）。Retry 只重放安全
  /// 读取（GET）——不会重放上次写入，结果未知不重放的语义保持不变。
  Widget _errorCard(BuildContext context) => Semantics(
    liveRegion: true,
    child: ErrorStateCard(
      message: _error ?? '',
      onRetry: _load,
      retryEnabled: !_loading,
    ),
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
