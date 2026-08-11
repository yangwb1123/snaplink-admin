import 'dart:math';

import 'package:flutter/material.dart';
import 'package:sso_admin/i18n/localized_text.dart';
import 'package:sso_admin/api/snaplink_admin_api.dart';
import 'package:sso_admin/widgets/confirm_dialog.dart';
import 'package:sso_admin/widgets/empty_state.dart';
import 'package:sso_admin/widgets/paginated_list.dart';
import 'package:sso_admin/widgets/skeleton_list.dart';

import 'scim_browser_widgets.dart';
import 'scim_group_dialog.dart';
import 'scim_models.dart';
import 'scim_patch_dialog.dart';
import 'scim_resource_detail_dialog.dart';
import 'scim_user_dialog.dart';

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

  String get _path => widget.kind.path;

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
      if (mounted) setState(() => _error = 'Could not load the directory.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
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
      title: 'Delete SCIM ${widget.kind.singular.toLowerCase()}?',
      message: widget.kind == ScimResourceKind.users
          ? 'Permanently delete $id from the identity directory. '
                'Deactivation is safer when access may need to be restored.'
          : 'Permanently delete $id and its role definition. Existing '
                'membership assignments will no longer grant this role.',
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
      if (mounted) setState(() => _error = 'Could not load resource details.');
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: LocalizedText(success)));
      await _load(startIndex: resetToFirst ? 1 : _page?.startIndex);
    } on SnaplinkAdminApiError catch (error) {
      if (mounted) setState(() => _error = _errorMessage(error));
    } catch (_) {
      if (mounted) setState(() => _error = 'The SCIM operation failed.');
    } finally {
      if (mounted) setState(() => _mutating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_unavailable) {
      return ScimUnavailable(kind: widget.kind, onRetry: _load);
    }
    final page = _page;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              LocalizedText(
                'SCIM ${widget.kind.collection}',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const Spacer(),
              IconButton(
                onPressed: _loading || _mutating ? null : _load,
                icon: const Icon(Icons.refresh),
                tooltip: 'Refresh'.localized,
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: _mutating ? null : _create,
                icon: const Icon(Icons.add),
                label: LocalizedText(
                  'Create ${widget.kind.singular.toLowerCase()}',
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ScimQueryBar(
            kind: widget.kind,
            filterController: _filterController,
            startIndexController: _startIndexController,
            count: _count,
            sortBy: _sortBy,
            descending: _descending,
            busy: _loading || _mutating,
            onCountChanged: (value) => setState(() => _count = value),
            onSortChanged: (value) => setState(() => _sortBy = value),
            onDescendingChanged: (value) => setState(() => _descending = value),
            onApply: _load,
          ),
          if (_error != null) _errorCard(context),
          if (_loading && page == null)
            const Expanded(child: SkeletonListTile(itemCount: 6))
          else if (page != null)
            Expanded(
              child: Column(
                children: [
                  if (_loading) const LinearProgressIndicator(),
                  Expanded(
                    child: page.resources.isEmpty
                        ? const EmptyState(
                            variant: EmptyStateVariant.empty,
                            title: 'No resources match this query.',
                          )
                        : ListView.builder(
                            itemCount: page.resources.length,
                            itemBuilder: (context, index) {
                              final resource = page.resources[index];
                              return ScimResourceTile(
                                kind: widget.kind,
                                resource: resource,
                                onTap: _mutating
                                    ? () {}
                                    : () => _showDetail(resource),
                              );
                            },
                          ),
                  ),
                  // 光标语义：page 传 null（无“Page null”胶囊），
                  // 汇总文案与现运行格式完全同形（U+2013 en-dash）。
                  PaginationControls(
                    page: null,
                    total: null,
                    summaryLabel: page.totalResults == 0
                        ? '0 results'
                        : '{start}–{end} of {total}',
                    summaryArgs: page.totalResults == 0
                        ? null
                        : {
                            'start': '${page.startIndex}',
                            'end':
                                '${page.itemsPerPage == 0 ? page.startIndex : page.startIndex + page.itemsPerPage - 1}',
                            'total': '${page.totalResults}',
                          },
                    canGoBack: page.hasPrevious && !(_loading || _mutating),
                    canGoNext: page.hasNext && !(_loading || _mutating),
                    onPrevious: () =>
                        _load(startIndex: max(1, page.startIndex - _count)),
                    onNext: () =>
                        _load(startIndex: page.startIndex + page.itemsPerPage),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _errorCard(BuildContext context) => Card(
    color: Theme.of(context).colorScheme.errorContainer,
    child: ListTile(
      leading: const Icon(Icons.error_outline),
      title: LocalizedText(_error!),
      trailing: TextButton.icon(
        onPressed: _loading ? null : _load,
        icon: const Icon(Icons.refresh),
        label: const LocalizedText('Retry'),
      ),
    ),
  );

  String _errorMessage(SnaplinkAdminApiError error) =>
      'SCIM request failed (${error.status}): ${error.toString()}';
}
