import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sso_admin/i18n/localized_text.dart';
import 'package:sso_admin/i18n/app_strings.dart';
import 'package:sso_admin/api/snaplink_admin_api.dart';
import 'package:sso_admin/widgets/app_snackbar.dart';
import 'package:sso_admin/widgets/confirm_dialog.dart';
import 'package:sso_admin/widgets/empty_state.dart';
import 'package:sso_admin/widgets/paginated_list.dart';
import 'package:sso_admin/widgets/async_view.dart';
import 'package:sso_admin/widgets/skeleton_list.dart';
import '../admin_module_groups.dart';
import 'scim_browser_widgets.dart';
import 'scim_group_dialog.dart';
import 'scim_models.dart';
import 'scim_patch_dialog.dart';
import 'scim_resource_detail_dialog.dart';
import 'scim_user_dialog.dart';

part 'scim_resource_browser_view.dart';

class ScimResourceBrowser extends StatefulWidget {
  final SnaplinkAdminApi api;
  final ScimResourceKind kind;
  const ScimResourceBrowser({super.key, required this.api, required this.kind});
  @override
  State<ScimResourceBrowser> createState() => _ScimResourceBrowserState();
}

class _ScimResourceBrowserState extends State<ScimResourceBrowser> {
  final _filterController = TextEditingController();
  final _startIndexController = TextEditingController(text: '1');
  ScimListPage? _page;
  String _sortBy = '';
  int _count = 50;
  bool _descending = false;
  bool _loading = false;
  bool _mutating = false;
  bool _unavailable = false;
  String? _error;

  /// 上次已应用的查询签名；筛选/排序/条数变化时 Apply 清空分页回第一页（R46）。
  (String, int, String, bool)? _lastQuery;
  String get _path => widget.kind.path;
  Color get _accent => adminModuleIconColor('scim-directory');
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _filterController.dispose();
    _startIndexController.dispose();
    super.dispose();
  }

  Future<void> _load({int? startIndex}) async {
    final parsedStart =
        startIndex ?? int.tryParse(_startIndexController.text.trim()) ?? 1;
    final target = max(1, parsedStart);
    setState(() {
      _loading = true;
      _error = null;
      _unavailable = false;
      _startIndexController.text = '$target';
    });
    try {
      final filter = _filterController.text.trim();
      final data = await widget.api.get(
        _path,
        query: {
          'startIndex': '$target',
          'count': '$_count',
          if (filter.isNotEmpty) 'filter': filter,
          if (_sortBy.isNotEmpty) 'sortBy': _sortBy,
          if (_sortBy.isNotEmpty)
            'sortOrder': _descending ? 'descending' : 'ascending',
        },
      );
      if (!mounted) return;
      setState(() => _page = ScimListPage.fromJson(data));
    } on SnaplinkAdminApiError catch (error) {
      if (!mounted) return;
      setState(() {
        if (error.status == 404 || error.status == 501) {
          _unavailable = true;
          _page = null;
        } else {
          _error = _errorMessage(error);
        }
      });
    } catch (_) {
      if (mounted) {
        setState(() => _error = context.tr('Could not load the directory.'));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Apply 语义：查询签名（筛选/条数/排序）变化 → 回 startIndex=1；
  /// 仅页码变化时保留原位（R46 三态联动）。
  void _applyQuery() {
    final sig = (_filterController.text.trim(), _count, _sortBy, _descending);
    final changed = sig != _lastQuery;
    _lastQuery = sig;
    _load(startIndex: changed ? 1 : null);
  }

  Future<void> _create() async {
    final body = await _showResourceForm();
    if (body == null || !mounted) return;
    await _mutate(
      () => widget.api.post(_path, body, scimContentType),
      '${widget.kind.singular} created.',
      resetToFirst: true,
    );
  }

  Future<void> _replace(Map<String, dynamic> resource) async {
    final id = resource['id']?.toString() ?? '';
    if (id.isEmpty) return;
    final body = await _showResourceForm(resource);
    if (body == null || !mounted) return;
    await _mutate(
      () =>
          _writeResource(method: 'PUT', id: id, resource: resource, body: body),
      '${widget.kind.singular} replaced.',
    );
  }

  Future<void> _patch(Map<String, dynamic> resource) async {
    final id = resource['id']?.toString() ?? '';
    if (id.isEmpty) return;
    final body = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => ScimPatchDialog(kind: widget.kind, resourceId: id),
    );
    if (body == null || !mounted) return;
    await _mutate(
      () => _writeResource(
        method: 'PATCH',
        id: id,
        resource: resource,
        body: body,
      ),
      '${widget.kind.singular} patched.',
    );
  }

  Future<void> _delete(Map<String, dynamic> resource) async {
    final id = resource['id']?.toString() ?? '';
    if (id.isEmpty) return;
    final confirmed = await ConfirmDialog.show(
      context,
      title: context.tr('Delete SCIM {resource}?', {
        'resource': widget.kind.singular.toLowerCase(),
      }),
      message: widget.kind == ScimResourceKind.users
          ? context.tr(
              'Permanently delete SCIM user {id}. Deactivation is safer when access may need to be restored.',
              {'id': id},
            )
          : context.tr(
              'Permanently delete SCIM group {id} and its role definition. Existing membership assignments will no longer grant this role.',
              {'id': id},
            ),
      confirmLabel: 'Delete permanently',
      confirmText: id,
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    await _mutate(
      () => _writeResource(method: 'DELETE', id: id, resource: resource),
      '${widget.kind.singular} deleted.',
    );
  }

  Future<Map<String, dynamic>> _writeResource({
    required String method,
    required String id,
    required Map<String, dynamic> resource,
    Object? body,
  }) {
    final path = '$_path/${Uri.encodeComponent(id)}';
    final meta = resource['meta'];
    final etag = meta is Map ? meta['version']?.toString().trim() ?? '' : '';
    if (etag.isNotEmpty) {
      return widget.api.mutateIfMatch(
        method: method,
        path: path,
        etag: etag,
        body: body,
        contentType: scimContentType,
      );
    }
    return switch (method) {
      'PUT' => widget.api.put(path, body, scimContentType),
      'PATCH' => widget.api.patch(path, body, scimContentType),
      'DELETE' => widget.api.delete(path, body, scimContentType),
      _ => throw ArgumentError.value(method, 'method'),
    };
  }

  Future<Map<String, dynamic>?> _showResourceForm([
    Map<String, dynamic>? existing,
  ]) async {
    if (widget.kind == ScimResourceKind.users) {
      final draft = await showDialog<ScimUserDraft>(
        context: context,
        builder: (_) => ScimUserDialog(existing: existing),
      );
      return draft?.toJson();
    }
    final draft = await showDialog<ScimGroupDraft>(
      context: context,
      builder: (_) => ScimGroupDialog(existing: existing),
    );
    return draft?.toJson();
  }

  Future<void> _showDetail(Map<String, dynamic> summary) async {
    final id = summary['id']?.toString() ?? '';
    if (id.isEmpty) return;
    setState(() {
      _mutating = true;
      _error = null;
    });
    Map<String, dynamic>? resource;
    try {
      resource = await widget.api.get(
        '$_path/${Uri.encodeComponent(id)}',
        forceRefresh: true,
      );
    } on SnaplinkAdminApiError catch (error) {
      if (mounted) setState(() => _error = _errorMessage(error));
    } catch (_) {
      if (mounted) {
        setState(() => _error = context.tr('Could not load resource details.'));
      }
    } finally {
      if (mounted) setState(() => _mutating = false);
    }
    if (!mounted || resource == null) return;
    final action = await showDialog<ScimDetailAction>(
      context: context,
      builder: (_) =>
          ScimResourceDetailDialog(kind: widget.kind, resource: resource!),
    );
    if (!mounted || action == null) return;
    switch (action) {
      case ScimDetailAction.replace:
        await _replace(resource);
      case ScimDetailAction.patch:
        await _patch(resource);
      case ScimDetailAction.delete:
        await _delete(resource);
    }
  }

  Future<void> _mutate(
    Future<Map<String, dynamic>> Function() operation,
    String success, {
    bool resetToFirst = false,
  }) async {
    setState(() {
      _mutating = true;
      _error = null;
    });
    try {
      await operation();
      if (!mounted) return;
      showAppSnackBar(context, content: LocalizedText(success));
      await _load(startIndex: resetToFirst ? 1 : _page?.startIndex);
    } on SnaplinkAdminApiError catch (error) {
      if (mounted) setState(() => _error = _errorMessage(error));
    } catch (_) {
      if (mounted) {
        setState(() => _error = context.tr('The SCIM operation failed.'));
      }
    } finally {
      if (mounted) setState(() => _mutating = false);
    }
  }

  void _setCount(int value) {
    setState(() => _count = value);
  }

  void _setSortBy(String value) {
    setState(() => _sortBy = value);
  }

  void _setDescending(bool value) {
    setState(() => _descending = value);
  }

  @override
  Widget build(BuildContext context) => _buildScimResourceBrowser(context);

  /// 空态“清除筛选”：清空查询框并重新加载。
  void _clearFilter() {
    _filterController.clear();
    _load();
  }

  String _errorMessage(SnaplinkAdminApiError error) {
    final detail = context.tr('SCIM request failed ({status}): {error}', {
      'status': '${error.status}',
      'error': error.toString(),
    });
    if (error.status == 412) {
      return '$detail ${context.tr('The data may have changed since you last loaded this page.')}';
    }
    return detail;
  }
}
