import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sso_admin/api/sso_client.dart';
import 'package:sso_admin/i18n/app_strings.dart';
import 'package:sso_admin/i18n/localized_text.dart';
import 'package:sso_admin/services/browser_navigation.dart';
import 'package:sso_admin/services/operator_persona.dart';
import 'package:sso_admin/widgets/admin_breadcrumb.dart';
import 'package:sso_admin/widgets/admin_data_table.dart';
import 'package:sso_admin/widgets/admin_list_header.dart';
import 'package:sso_admin/widgets/app_snackbar.dart';
import 'package:sso_admin/widgets/batch_action_bar.dart';
import 'package:sso_admin/widgets/batch_feedback.dart';
import 'package:sso_admin/widgets/batch_selection.dart';
import 'package:sso_admin/widgets/confirm_dialog.dart';
import 'package:sso_admin/widgets/empty_state.dart';
import 'package:sso_admin/widgets/paginated_list.dart';
import 'package:sso_admin/widgets/pull_to_refresh.dart';
import 'package:sso_admin/widgets/search_filter_bar.dart';
import 'package:sso_admin/widgets/skeleton_list.dart';
import 'package:sso_admin/widgets/status_chip.dart';
import 'package:sso_admin/widgets/tight_dropdown.dart';
import 'package:sso_admin/widgets/async_view.dart';
import 'package:sso_admin/widgets/status_filter_dropdown.dart';
import 'admin_module_groups.dart';
import 'admin_route.dart';
import 'client_detail_secret_card.dart';
import 'client_form_dialog.dart';
import 'client_secret_lifecycle.dart';
import 'admin_ops_helpers.dart';
import 'list_metrics.dart';
part 'clients_tab_view.dart';
part 'clients_tab_sections.dart';

class ClientsTab extends StatefulWidget {
  final SSOAdminClient client;
  final OperatorPersona persona;
  const ClientsTab({
    super.key,
    required this.client,
    this.persona = OperatorPersona.general,
  });
  @override
  State<ClientsTab> createState() => _ClientsTabState();
}

class _ClientsTabState extends State<ClientsTab>
    with BatchSelection<ClientsTab>, PaginatedListMixin<ClientsTab> {
  final _filterCtrl = TextEditingController();
  late Future<SSOAdminListPage> _future;
  SSOAdminListPage? _lastPage;
  int _reqSeq = 0;
  var _pageSize = 100, _orderBy = 'id';
  String? _sortColumn = 'id';
  bool _sortAscending = true;
  var _expiringOnly = false, _statusFilter = 'all';
  bool _busy = false;
  bool _secretRotationOutcomeUnknown = false;
  late final void Function() _cancelPopState;
  Color get _accent => adminModuleIconColor('clients');
  @override
  bool? get canGoNext => _lastPage?.nextPageToken != null;
  @override
  void initState() {
    super.initState();
    _future = _loadPage();
    _handleRoute();
    _cancelPopState = BrowserNavigation.listenToLocationChange(() {
      if (mounted) _handleRoute();
    });
  }

  @override
  void dispose() {
    _cancelPopState();
    _filterCtrl.dispose();
    super.dispose();
  }

  void _handleRoute() {
    final route = AdminRoute.current();
    if (route.module != 'clients') return;
    if (route.isNew) {
      _openDialog();
    } else if (route.isEdit) {
      _openEditForId(route.resourceId);
    }
  }

  Future<void> _openEditForId(String id) async {
    try {
      final client = await widget.client.getClient(id);
      if (!mounted) return;
      await _openDialog(existing: client);
    } catch (e) {
      debugPrint('clients_tab edit error: $e');
    }
    if (mounted) AdminRoute.back('clients');
  }

  Future<SSOAdminListPage> _loadPage() async {
    final seq = ++_reqSeq;
    if (_expiringOnly) {
      var items = await widget.client.listExpiringClients();
      final text = _filterCtrl.text.trim().toLowerCase();
      if (text.isNotEmpty) {
        items = items
            .where(
              (c) =>
                  (c['id']?.toString() ?? '').toLowerCase().contains(text) ||
                  (c['name']?.toString() ?? '').toLowerCase().contains(text),
            )
            .toList();
      }
      if (_statusFilter != 'all') {
        final active = _statusFilter == 'active';
        items = items.where((c) => (c['active'] == true) == active).toList();
      }
      final desc = _orderBy.startsWith('-');
      final key = desc ? _orderBy.substring(1) : _orderBy;
      items.sort(
        (a, b) =>
            (a[key]?.toString() ?? '').compareTo(b[key]?.toString() ?? ''),
      );
      if (desc) items = items.reversed.toList();
      final page = SSOAdminListPage(
        items: items,
        nextPageToken: null,
        totalSize: items.length,
      );
      if (seq == _reqSeq) _lastPage = page;
      return page;
    }
    final text = _filterCtrl.text.trim();
    final query = _statusFilter == 'all'
        ? text
        : text.isEmpty
        ? 'active:${_statusFilter == 'active'}'
        : '$text and active:${_statusFilter == 'active'}';
    final page = await widget.client.listClients(
      pageToken: currentPageToken,
      pageSize: _pageSize,
      orderBy: _orderBy,
      filter: query,
    );
    if (seq == _reqSeq) _lastPage = page;
    return page;
  }

  void _onSort(String column) {
    if (column == 'status') return;
    setState(() {
      if (_sortColumn != column) {
        _sortColumn = column;
        _sortAscending = true;
      } else if (_sortAscending) {
        _sortAscending = false;
      } else {
        _sortColumn = null;
        _sortAscending = true;
      }
      _orderBy = (_sortAscending ? '' : '-') + (_sortColumn ?? 'id');
    });
    _reload();
  }

  Future<void> _reload() {
    clearSelection();
    setState(() {
      resetPagination();
      _future = _loadPage();
    });
    return _future;
  }

  void _clearFilter() {
    _filterCtrl.clear();
    _statusFilter = 'all';
    _expiringOnly = false;
    _reload();
  }

  void _goPrevious() {
    if (!canGoBack) return;
    setState(() {
      goPrevious();
      _future = _loadPage();
    });
  }

  void _goNext(SSOAdminListPage page) {
    if (page.nextPageToken == null) return;
    setState(() {
      goNext(page.nextPageToken, page: page);
      _future = _loadPage();
    });
  }

  void _retryPage() {
    setState(() {
      _future = _loadPage();
    });
  }

  Future<void> _openDialog({Map<String, dynamic>? existing}) async {
    final changed = await showDialog<bool>(
      context: context,
      builder: (_) =>
          ClientFormDialog(client: widget.client, existing: existing),
    );
    if (changed == true) _reload();
    if (mounted) AdminRoute.back('clients');
  }

  static const _copy = <String, (String, String, String, String?)>{
    'approve': (
      'Approve client?',
      'Approve {clientId} for use on this authorization server?',
      'Approve',
      'Client {id} approved.',
    ),
    'reject': (
      'Reject client?',
      'Reject the pending client registration for {clientId}?',
      'Reject',
      'Client {id} rejected.',
    ),
    'delete': (
      'Delete client?',
      'Delete {clientId} permanently? Existing tokens and integrations may stop working.',
      'Delete permanently',
      'Client {id} deleted.',
    ),
  };
  Future<void> _rotateSecret(Map<String, dynamic> c) async {
    final id = c['id']?.toString() ?? '';
    if (id.isEmpty || _busy || _secretRotationOutcomeUnknown) return;
    final confirmed = await ConfirmDialog.show(
      context,
      title: context.tr('Rotate client secret?'),
      message: context.tr(
        'The current secret for {clientId} remains valid for 24 hours. Update every integration with the new one-time value before that window closes.',
        {'clientId': id},
      ),
      confirmLabel: 'Rotate secret',
      destructive: true,
      confirmText: id,
    );
    if (!confirmed) return;
    setState(() => _busy = true);
    try {
      final rotation = await widget.client.rotateClientSecretWithPolicy(id);
      if (!mounted) return;
      final secret = rotation['secret']?.toString() ?? '';
      if (secret.isEmpty) {
        setState(() => _secretRotationOutcomeUnknown = true);
        showAppSnackBar(
          context,
          content: LocalizedText(
            'The secret was rotated, but its one-time value was not returned. Reconcile client state before retrying.',
          ),
          kind: AppSnackBarKind.error,
        );
        await _reload();
        return;
      }
      await showRotatedClientSecret(
        context,
        secret,
        expiryLabel: clientSecretExpiryLabel(context, rotation),
      );
      _reload();
    } on SSOError catch (e) {
      if (!mounted) return;
      final unknown = AdminOpsHelpers.isAmbiguousWriteStatus(e.status);
      if (unknown) {
        setState(() => _secretRotationOutcomeUnknown = true);
        showAppSnackBar(
          context,
          content: LocalizedText(
            'Secret rotation result is unknown. Reconcile client state before retrying.',
          ),
          kind: AppSnackBarKind.error,
        );
      } else {
        showAppSnackBar(
          context,
          content: Text(e.toString()),
          kind: AppSnackBarKind.error,
        );
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _secretRotationOutcomeUnknown = true);
      showAppSnackBar(
        context,
        content: LocalizedText(
          'Secret rotation result is unknown. Reconcile client state before retrying.',
        ),
        kind: AppSnackBarKind.error,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _acknowledgeSecretRotation() async {
    final confirmed = await ConfirmDialog.show(
      context,
      title: 'Client secret state reconciled?',
      message:
          'Confirm only after checking the client and its integrations in a safe read. This unlocks secret rotation; it does not prove the previous request failed.',
      confirmLabel: 'Unlock secret rotation',
      destructive: true,
      confirmText: 'RECONCILED',
    );
    if (!confirmed || !mounted) return;
    setState(() => _secretRotationOutcomeUnknown = false);
  }

  Future<void> _runBatch(
    String action,
    Future<void> Function(String) run,
  ) async {
    final ids = selected.toList();
    if (ids.isEmpty) return;
    final approve = action == 'Approve';
    final confirmed = await ConfirmDialog.show(
      context,
      title: context.tr(
        approve ? 'Approve {n} clients?' : 'Reject {n} clients?',
        {'n': ids.length},
      ),
      message: context.tr(
        approve
            ? 'This will approve {n} selected clients in one operation.'
            : 'This will reject {n} selected clients in one operation.',
        {'n': ids.length},
      ),
      confirmLabel: action,
    );
    if (!confirmed) return;
    setState(() => _busy = true);
    try {
      final results = await Future.wait(
        ids.map((id) async {
          try {
            await run(id);
            return null;
          } catch (e) {
            return '$id: $e';
          }
        }),
      );
      final failures = results.whereType<String>().toList();
      final ok = ids.length - failures.length;
      if (!mounted) return;
      clearSelection();
      final message = failures.isEmpty
          ? context.tr('{action} completed for {n} of {total} clients.', {
              'action': action,
              'n': ok,
              'total': ids.length,
            })
          : context.tr('{action}: {n} succeeded, {failed} failed. {details}', {
              'action': action,
              'n': ok,
              'failed': failures.length,
              'details': failures.take(3).join('; '),
            });
      showBatchResultSnackBar(context, message: message, failures: failures);
      _reload();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => _buildClientsTab(context);
}
