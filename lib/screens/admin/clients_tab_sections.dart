part of 'clients_tab.dart';

extension _ClientsTabSections on _ClientsTabState {
  /// Narrow layouts keep each client as one touch target instead of forcing a
  /// wide relational table into horizontal scrolling. The ID remains copyable,
  /// while the secret column is represented as a label/value in the card.
  Widget _mobileList(List<Map<String, dynamic>> items) {
    String cid(int i) => items[i]['id']?.toString() ?? '';

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final c = items[i];
        final id = cid(i);
        final name = c['name']?.toString() ?? '';
        final expiry = clientSecretExpiryLabel(context, c);
        return Card(
          margin: EdgeInsets.zero,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => selecting
                ? toggleSelect(id)
                : AdminRoute.go('clients', resourceId: id),
            onLongPress: selecting ? null : () => toggleSelect(id),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 48,
                    child: Checkbox(
                      value: selected.contains(id),
                      onChanged: _busy ? null : (_) => toggleSelect(id),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  name,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              c['active'] == true
                                  ? StatusChip.active()
                                  : StatusChip.inactive(),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            AppStrings.of(context).clientId,
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                          CopyableCell(
                            text: id,
                            contextProvider: () => context,
                            enabled: !selecting,
                          ),
                          const SizedBox(height: 4),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                AppStrings.of(context).clientSecret,
                                style: Theme.of(context).textTheme.labelSmall,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  expiry,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onSurfaceVariant,
                                      ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  _clientActions(c),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _clientActions(Map<String, dynamic> c) => PopupMenuButton<String>(
    enabled: !_busy,
    onSelected: (value) => switch (value) {
      'edit' => AdminRoute.go(
        'clients',
        action: 'edit',
        resourceId: c['id']?.toString() ?? '',
      ),
      'rotate' => _rotateSecret(c),
      'approve' => _clientAction(c, 'approve'),
      'reject' => _clientAction(c, 'reject'),
      'delete' => _clientAction(c, 'delete'),
      _ => null,
    },
    itemBuilder: (context) => [
      const PopupMenuItem(value: 'edit', child: LocalizedText('Edit')),
      PopupMenuItem(
        value: 'rotate',
        enabled: !_secretRotationOutcomeUnknown,
        child: const LocalizedText('Rotate secret'),
      ),
      const PopupMenuItem(value: 'approve', child: LocalizedText('Approve')),
      const PopupMenuItem(value: 'reject', child: LocalizedText('Reject')),
      const PopupMenuItem(value: 'delete', child: LocalizedText('Delete')),
    ],
  );

  /// 单客户端动作公共骨架：确认（破坏性需输入 ID）→ 调用 → 报告 → 刷新。
  /// 进行中 [_busy] 禁行全部行菜单（防重入，与批量一致）。
  Future<void> _clientAction(Map<String, dynamic> c, String kind) async {
    final id = c['id']?.toString() ?? '';
    if (id.isEmpty || _busy) return;
    final (titleKey, msgKey, confirm, snack) = _ClientsTabState._copy[kind]!;
    final destructive = kind != 'approve';
    final confirmed = await ConfirmDialog.show(
      context,
      title: context.tr(titleKey),
      message: context.tr(msgKey, {'clientId': id}),
      confirmLabel: confirm,
      destructive: destructive,
      confirmText: destructive ? id : null,
    );
    if (!confirmed) return;
    // ignore: invalid_use_of_protected_member
    setState(() => _busy = true);
    try {
      await switch (kind) {
        'approve' => widget.client.approveClient(id),
        'reject' => widget.client.rejectClient(id),
        _ => widget.client.deleteClient(id),
      };
      if (!mounted) return;
      if (snack != null) {
        showAppSnackBar(
          context,
          content: LocalizedText(snack, args: {'id': id}),
        );
      }
      _reload();
    } on SSOError catch (e) {
      if (!mounted) return;
      showAppSnackBar(
        context,
        content: Text(e.toString()),
        kind: AppSnackBarKind.error,
      );
    } finally {
      // ignore: invalid_use_of_protected_member
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _dataTable(BuildContext context, List<Map<String, dynamic>> items) {
    String cid(int i) => items[i]['id']?.toString() ?? '';
    return AdminDataTable(
      scrollable: true,
      minWidth: 980,
      sortColumn: _sortColumn,
      sortAscending: _sortAscending,
      onSort: _onSort,
      onRowTap: selecting
          ? (i) => toggleSelect(cid(i))
          : (i) => AdminRoute.go('clients', resourceId: cid(i)),
      onRowLongPress: selecting ? null : (i) => toggleSelect(cid(i)),
      columns: [
        if (selecting)
          AdminDataColumn(
            id: 'select',
            label: '',
            width: 44,
            builder: (context, i) => Checkbox(
              value: selected.contains(cid(i)),
              onChanged: _busy ? null : (_) => toggleSelect(cid(i)),
            ),
          ),
        AdminDataColumn(
          id: 'id',
          label: AppStrings.of(context).clientId,
          width: 190,
          sortable: true,
          builder: (context, i) => CopyableCell(
            text: cid(i),
            contextProvider: () => context,
            enabled: !selecting,
          ),
        ),
        AdminDataColumn(
          id: 'name',
          label: 'NAME',
          width: 180,
          sortable: true,
          builder: (context, i) => TableCellText(
            items[i]['name']?.toString() ?? '',
            bold: true,
            maxLines: 2,
          ),
        ),
        AdminDataColumn(
          id: 'status',
          label: 'STATUS',
          width: 160,
          builder: (context, i) => items[i]['active'] == true
              ? StatusChip.active()
              : StatusChip.inactive(),
        ),
        // R52：TOKEN（token_strategy）列为冗余——客户端详情页已展示
        // 'Token strategy'（client_detail_screen.dart），列表收进 6 列内。
        AdminDataColumn(
          id: 'expiry',
          label: AppStrings.of(context).clientSecret,
          width: 170,
          builder: (context, i) => TableCellText(
            clientSecretExpiryLabel(context, items[i]),
            muted: true,
          ),
        ),
        AdminDataColumn(
          id: 'actions',
          label: '',
          width: 60,
          builder: (context, i) => _clientActions(items[i]),
        ),
      ],
      itemCount: items.length,
      rowBuilder: (context, i) => const SizedBox.shrink(),
    );
  }
}
