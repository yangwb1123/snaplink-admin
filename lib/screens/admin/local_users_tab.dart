import 'package:flutter/material.dart';
import 'package:sso_admin/api/snaplink_admin_api.dart';
import 'package:sso_admin/i18n/app_strings.dart';
import 'package:sso_admin/i18n/localized_text.dart';
import 'package:sso_admin/widgets/admin_breadcrumb.dart';
import 'package:sso_admin/widgets/admin_data_table.dart';
import 'package:sso_admin/widgets/admin_list_header.dart';
import 'package:sso_admin/widgets/app_snackbar.dart';
import 'package:sso_admin/widgets/async_view.dart';
import 'package:sso_admin/widgets/batch_action_bar.dart';
import 'package:sso_admin/widgets/batch_feedback.dart';
import 'package:sso_admin/widgets/batch_selection.dart';
import 'package:sso_admin/widgets/confirm_dialog.dart';
import 'package:sso_admin/widgets/empty_state.dart';
import 'package:sso_admin/widgets/paginated_list.dart';
import 'package:sso_admin/widgets/pull_to_refresh.dart';
import 'package:sso_admin/widgets/user_avatar.dart';
import 'admin_module_groups.dart';
import 'local_user_validation.dart';

/// Password-authenticated directory users.
///
/// Intentionally separate from the federated `/admin/users` surface: local
/// users own a username + password credential, federated users do not.
class LocalUsersTab extends StatefulWidget {
  final SnaplinkAdminApi api;
  final SnaplinkAdminCapabilities capabilities;
  const LocalUsersTab({
    super.key,
    required this.api,
    required this.capabilities,
  });
  @override
  State<LocalUsersTab> createState() => _LocalUsersTabState();
}

class _LocalUsersTabState extends State<LocalUsersTab>
    with BatchSelection<LocalUsersTab> {
  static const _basePath = '/api/v1/admin/local-users', _pageSize = 25;

  List<Map<String, dynamic>> _users = const [];
  String? _error;
  int _page = 1, _total = 0;
  bool _loading = false, _mutating = false; // 含批量删除进行中（禁按钮 + 进度）。
  /// 模块强调色（identity 组 indigo-violet）：页内图标统一按组色上色。
  Color get _accent => adminModuleIconColor('local-users');
  bool get _available =>
      widget.capabilities.hasAnyPathPrefix(_basePath) ||
      SnaplinkAdminOperationCatalog.hasDocumentedPathPrefix(_basePath);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({int? page}) async {
    if (!_available) return;
    final target = page ?? _page;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await widget.api.get(
        _basePath,
        query: {'page': '$target', 'limit': '$_pageSize'},
      );
      final values = data['users'] as List? ?? const [];
      if (!mounted) return;
      setState(() {
        _page = target;
        _total = (data['total'] as num?)?.toInt() ?? values.length;
        _users = values
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList(growable: false);
      });
    } on SnaplinkAdminApiError catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openForm([Map<String, dynamic>? existing]) async {
    final draft = await showDialog<_LocalUserDraft>(
      context: context,
      builder: (_) => _LocalUserDialog(existing: existing),
    );
    if (draft == null || !mounted) return;
    setState(() => _mutating = true);
    try {
      if (existing == null) {
        await widget.api.post(_basePath, draft.createBody);
      } else {
        final id = existing['id']?.toString() ?? '';
        await widget.api.put(
          '$_basePath/${Uri.encodeComponent(id)}',
          draft.updateBody,
        );
      }
      if (!mounted) return;
      showAppSnackBar(
        context,
        content: LocalizedText(
          existing == null ? 'Local user created.' : 'Local user updated.',
        ),
      );
      await _load(page: existing == null ? 1 : _page);
    } on SnaplinkAdminApiError catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _mutating = false);
    }
  }

  /// 批量删除：确认 → 并行执行 → 明细报告；进行中 _mutating 禁按钮（防重复提交）。
  Future<void> _batchDelete() async {
    final ids = selected.toList();
    if (ids.isEmpty) return;
    final confirmed = await ConfirmDialog.show(
      context,
      title: context.tr('Delete {n} local users?', {'n': ids.length}),
      message: context.tr(
        'This will delete {n} selected local users and their password credentials. This cannot be undone.',
        {'n': ids.length},
      ),
      confirmLabel: 'Delete users',
      destructive: true,
    );
    if (!confirmed) return;
    setState(() => _mutating = true);
    final results = await Future.wait(
      ids.map((id) async {
        try {
          await widget.api.delete('$_basePath/${Uri.encodeComponent(id)}');
          return null;
        } catch (e) {
          return '$id: $e';
        }
      }),
    );
    if (!mounted) return;
    setState(() => _mutating = false);
    final failures = results.whereType<String>().toList();
    final ok = ids.length - failures.length;
    final pageEmptied = _users.isNotEmpty && ok == _users.length && _page > 1;
    clearSelection();
    final message = failures.isEmpty
        ? context.tr('Deleted {n} of {total} local users.', {
            'n': ok,
            'total': ids.length,
          })
        : context.tr('{action}: {n} succeeded, {failed} failed. {details}', {
            'action': 'Delete',
            'n': ok,
            'failed': failures.length,
            'details': failures.take(3).join('; '),
          });
    showBatchResultSnackBar(context, message: message, failures: failures);
    await _load(page: pageEmptied ? _page - 1 : _page); // 空页回退（对齐单删语义）
  }

  Widget _batchBar(BuildContext context) => BatchActionBar(
    selectedCount: selected.length,
    accent: _accent,
    isLoading: _mutating,
    actions: [
      BatchAction(
        label: 'Delete',
        icon: Icons.delete_outline,
        destructive: true,
        onPressed: _batchDelete,
      ),
    ],
    onClearSelection: clearSelection,
  );

  Future<void> _delete(Map<String, dynamic> user) async {
    final id = user['id']?.toString() ?? '';
    if (id.isEmpty) return;
    final label = user['username']?.toString() ?? id;
    final confirmed = await ConfirmDialog.show(
      context,
      title: context.tr('Delete local user?'),
      message: context.tr(
        'Delete {label} and its password credential? This cannot be undone.',
        {'label': label},
      ),
      confirmLabel: 'Delete user',
      destructive: true,
      confirmText: label,
    );
    if (!confirmed) return;
    setState(() => _mutating = true);
    try {
      await widget.api.delete('$_basePath/${Uri.encodeComponent(id)}');
      if (!mounted) return;
      showAppSnackBar(context, content: LocalizedText('Local user deleted.'));
      final nextPage = _users.length == 1 && _page > 1 ? _page - 1 : _page;
      await _load(page: nextPage);
    } on SnaplinkAdminApiError catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _mutating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_available) {
      return const EmptyState(
        variant: EmptyStateVariant.notEnabled,
        title: 'Local password users are not enabled on this replica.',
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AdminBreadcrumb(),
        AdminListHeader(
          title: AppStrings.of(context).localUsers,
          subtitle:
              'Password-authenticated accounts managed by this SSO server.',
          onRefresh: _load,
          actions: [
            FilledButton.icon(
              onPressed: _mutating ? null : _openForm,
              icon: const Icon(Icons.person_add_outlined),
              label: const LocalizedText('Create local user'),
            ),
            const SizedBox(width: 4),
            IconButton(
              onPressed: _loading || _mutating
                  ? null
                  : () {
                      clearSelection();
                      _load();
                    },
              tooltip: 'Refresh'.localized,
              icon: _loading || _mutating
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(Icons.refresh, color: _accent),
            ),
          ],
        ),
        if (selecting) ...[_batchBar(context), const SizedBox(height: 8)],
        Expanded(
          child: AsyncView<List<Map<String, dynamic>>>(
            loading: _loading,
            error: _error,
            data: _users,
            onRetry: _load,
            useSkeleton: true,
            skeletonDelay: const Duration(milliseconds: 150),
            emptyTitle: _page > 1 ? 'No data on this page' : 'No local users',
            emptySubtitle: _page > 1
                ? 'The data may have changed since you last loaded this page.'
                : 'Create the first password-authenticated account.',
            emptyActionLabel: _page > 1
                ? 'Back to first page'
                : 'Create local user',
            onEmptyAction: _page > 1 ? () => _load(page: 1) : _openForm,
            dataBuilder: (users) =>
                PullToRefresh(onRefresh: _load, child: _dataTable(users)),
          ),
        ),
        if (_total > _pageSize)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                PaginationControls(
                  page: _page,
                  total: _total,
                  canGoBack: _page > 1 && !_loading,
                  canGoNext: _page * _pageSize < _total && !_loading,
                  onPrevious: () => _load(page: _page - 1),
                  onNext: () => _load(page: _page + 1),
                ),
              ],
            ),
          ),
      ],
    );
  }

  /// 列表单元格主显示名（display_name 优先，回退 username）。
  String _display(Map<String, dynamic> user) {
    final name = user['display_name']?.toString() ?? '';
    return name.isNotEmpty ? name : user['username']?.toString() ?? '';
  }

  Widget _dataTable(List<Map<String, dynamic>> users) {
    String uid(int i) => users[i]['id']?.toString() ?? '';
    return AdminDataTable(
      scrollable: true,
      minWidth: 760,
      onRowTap: selecting ? (i) => toggleSelect(uid(i)) : null,
      onRowLongPress: selecting ? null : (i) => toggleSelect(uid(i)),
      columns: [
        if (selecting)
          AdminDataColumn(
            id: 'select',
            label: '',
            width: 44,
            builder: (context, i) => Checkbox(
              value: selected.contains(uid(i)),
              onChanged: (_) => toggleSelect(uid(i)),
            ),
          ),
        AdminDataColumn(
          id: 'user',
          label: 'USER',
          width: 300,
          cardPrimary: true,
          builder: (context, i) => Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              UserAvatar(name: uid(i), radius: 14),
              const SizedBox(width: 8),
              Flexible(
                child: TableCellText(
                  _display(users[i]),
                  bold: true,
                  maxLines: 1,
                ),
              ),
            ],
          ),
        ),
        AdminDataColumn(
          id: 'username',
          label: 'USERNAME',
          width: 180,
          builder: (context, i) {
            // 与显示名相同时不重复渲染（保持单实例文本）。
            final username = users[i]['username']?.toString() ?? '';
            return TableCellText(
              username == _display(users[i]) ? '' : username,
              muted: true,
            );
          },
        ),
        AdminDataColumn(
          id: 'email',
          label: 'EMAIL',
          builder: (context, i) =>
              TableCellText(users[i]['email']?.toString() ?? '', muted: true),
        ),
        AdminDataColumn(
          id: 'actions',
          label: '',
          width: 60,
          builder: (context, i) {
            final user = users[i];
            return PopupMenuButton<String>(
              enabled: !_mutating,
              onSelected: (action) {
                if (action == 'edit') _openForm(user);
                if (action == 'delete') _delete(user);
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'edit', child: LocalizedText('Edit')),
                PopupMenuItem(value: 'delete', child: LocalizedText('Delete')),
              ],
            );
          },
        ),
      ],
      itemCount: users.length,
      rowBuilder: (context, i) => const SizedBox.shrink(),
    );
  }
}

class _LocalUserDraft {
  final String username, email, displayName, password;

  const _LocalUserDraft({
    required this.username,
    required this.email,
    required this.displayName,
    required this.password,
  });

  Map<String, dynamic> get createBody => {
    'username': username,
    'email': email,
    'display_name': displayName,
    'password': password,
  };
  Map<String, dynamic> get updateBody => {
    'email': email,
    'display_name': displayName,
  };
}

class _LocalUserDialog extends StatefulWidget {
  final Map<String, dynamic>? existing;
  const _LocalUserDialog({this.existing});
  @override
  State<_LocalUserDialog> createState() => _LocalUserDialogState();
}

class _LocalUserDialogState extends State<_LocalUserDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _usernameCtrl,
      _emailCtrl,
      _nameCtrl,
      _passwordCtrl;

  bool get _editing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _usernameCtrl = TextEditingController(
      text: existing?['username']?.toString() ?? '',
    );
    _emailCtrl = TextEditingController(
      text: existing?['email']?.toString() ?? '',
    );
    _nameCtrl = TextEditingController(
      text:
          existing?['display_name']?.toString() ??
          existing?['name']?.toString() ??
          '',
    );
    _passwordCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _emailCtrl.dispose();
    _nameCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  /// 校验消息本地化：validator 返回目录键 → 渲染时按当前 locale 翻译。
  String? _validate(String? Function(String?) rule, String? value) =>
      rule(value) == null ? null : context.tr(rule(value)!);

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(
      context,
      _LocalUserDraft(
        username: _usernameCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        displayName: _nameCtrl.text.trim(),
        password: _passwordCtrl.text,
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    bool enabled = true,
    bool obscure = false,
    bool autofocus = false,
    TextInputType? keyboard,
    String? Function(String?)? validate,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextFormField(
      controller: controller,
      enabled: enabled,
      autofocus: autofocus,
      obscureText: obscure,
      keyboardType: keyboard,
      decoration: InputDecoration(labelText: label.localized),
      validator: validate,
    ),
  );

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: LocalizedText(_editing ? 'Edit local user' : 'Create local user'),
    content: SizedBox(
      width: 560,
      child: Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _field(
                controller: _usernameCtrl,
                label: 'Username',
                enabled: !_editing,
                autofocus: !_editing,
                validate: (v) => _validate(validateSnaplinkLocalUsername, v),
              ),
              _field(
                controller: _emailCtrl,
                label: 'Email',
                keyboard: TextInputType.emailAddress,
                validate: (v) => _validate(validateSnaplinkLocalEmail, v),
              ),
              _field(controller: _nameCtrl, label: 'Display name'),
              if (!_editing)
                _field(
                  controller: _passwordCtrl,
                  label: 'Initial password',
                  obscure: true,
                  validate: (v) =>
                      _validate(validateSnaplinkInitialPassword, v),
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
      FilledButton(onPressed: _submit, child: const LocalizedText('Save')),
    ],
  );
}
