import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'snaplink_admin_api.dart';
import 'governance_models.dart';

/// JSON is intentionally retained for schema-rich operations so the console
/// does not silently discard backend fields. Every write requires `CONFIRM`.
class GovernanceTab extends StatefulWidget {
  final SnaplinkAdminApi api;
  final SnaplinkAdminCapabilities capabilities;

  const GovernanceTab({
    super.key,
    required this.api,
    required this.capabilities,
  });

  @override
  State<GovernanceTab> createState() => _GovernanceTabState();
}

class _GovernanceTabState extends State<GovernanceTab> {
  static const _auditPath = '/api/v1/audit/events';
  static const _facetPath = '/api/v1/audit/facets';
  final _auditQuery = TextEditingController(text: '{"limit": 100}');
  final _resourceId = TextEditingController();
  final _writeBody = TextEditingController(text: '{}');
  final _confirm = TextEditingController();
  final Map<String, Map<String, dynamic>> _data = {};

  GovernanceWriteOperation _op = governanceWriteOperations.first;
  String? _error;
  bool _loading = false;
  bool _writing = false;

  bool _has(String method, String path) =>
      widget.capabilities.has(method, path) ||
      widget.capabilities.endpoints.any(
        (endpoint) =>
            endpoint.method == method && _route(endpoint.path) == _route(path),
      ) ||
      SnaplinkAdminOperationCatalog.endpoints.any(
        (endpoint) =>
            endpoint.method == method && _route(endpoint.path) == _route(path),
      );

  String _route(String path) => path
      .replaceAllMapped(RegExp(r'\{[A-Za-z_][A-Za-z0-9_]*\}'), (_) => ':id')
      .replaceAllMapped(RegExp(r':[A-Za-z_][A-Za-z0-9_]*'), (_) => ':id');

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void dispose() {
    _auditQuery.dispose();
    _resourceId.dispose();
    _writeBody.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    final reads = governanceReadSpecs
        .where((spec) => _has('GET', spec.path))
        .toList(growable: false);
    if (reads.isEmpty) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait(
        reads.map((spec) async {
          try {
            return (
              key: spec.key,
              data: await widget.api.get(spec.path),
              error: '',
            );
          } on SnaplinkAdminApiError catch (error) {
            return (
              key: spec.key,
              data: <String, dynamic>{},
              error: error.toString(),
            );
          }
        }),
      );
      if (!mounted) return;
      final failures = results
          .where((result) => result.error.isNotEmpty)
          .toList();
      setState(() {
        _data.addEntries(
          results
              .where((result) => result.error.isEmpty)
              .map((result) => MapEntry(result.key, result.data)),
        );
        if (failures.isNotEmpty) {
          _error =
              '${failures.length} optional governance source(s) could not be loaded.';
        }
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _read(GovernanceReadSpec spec) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final response = await widget.api.get(spec.path);
      if (mounted) setState(() => _data[spec.key] = response);
    } on SnaplinkAdminApiError catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _queryAudit() async {
    final query = _json(_auditQuery.text, 'Audit query');
    if (query == null) return;
    final parameters = query.map((key, value) => MapEntry(key, '$value'));
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final events = widget.api.get(_auditPath, query: parameters);
      final facets = _has('GET', _facetPath)
          ? widget.api.get(_facetPath, query: parameters)
          : null;
      final results = await Future.wait([events, ?facets]);
      if (mounted) {
        setState(() {
          _data['audit'] = results.first;
          if (facets != null) _data['facets'] = results.last;
        });
      }
    } on SnaplinkAdminApiError catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _runWrite() async {
    var path = _op.path;
    if (path.contains(':id')) {
      final id = _resourceId.text.trim();
      if (id.isEmpty) {
        setState(
          () => _error = 'Enter the affected snapshot, release, or change ID.',
        );
        return;
      }
      path = path.replaceAll(':id', Uri.encodeComponent(id));
    }
    final body = _json(_writeBody.text, 'Request body');
    if (body == null || !await _confirmed('Run ${_op.label}?')) return;
    setState(() {
      _writing = true;
      _error = null;
    });
    try {
      final result = _op.method == 'POST'
          ? await widget.api.post(path, body)
          : await widget.api.delete(path, body);
      if (!mounted) return;
      setState(() => _data['lastWrite'] = result);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('${_op.label} completed.')));
      await _refresh();
    } on SnaplinkAdminApiError catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _writing = false);
    }
  }

  Map<String, dynamic>? _json(String source, String label) {
    try {
      final value = jsonDecode(source.trim().isEmpty ? '{}' : source);
      if (value is Map) return Map<String, dynamic>.from(value);
    } on FormatException {
      // The validation error below names the unsafe input field.
    }
    setState(() => _error = '$label must be a JSON object.');
    return null;
  }

  Future<bool> _confirmed(String action) async {
    if (_confirm.text.trim() != 'CONFIRM') {
      setState(
        () => _error = 'Type CONFIRM before executing a write operation.',
      );
      return false;
    }
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Confirm governed operation'),
            content: Text(action),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: Colors.red),
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Run operation'),
              ),
            ],
          ),
        ) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Text(
              'Governance and operations',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const Spacer(),
            IconButton(
              onPressed: _loading || _writing ? null : _refresh,
              tooltip: 'Refresh',
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Text(
          'Operational evidence is read-only; every state-changing request is confirmed and sent as JSON. Routes not listed by runtime inventory remain available when Snaplink documents them; the server remains authoritative for optional features.',
        ),
        if (_error != null) _errorBanner(),
        if (_loading) const LinearProgressIndicator(),
        _readArea(context, 'Platform health', 'health'),
        _auditArea(context),
        _readArea(context, 'Compliance evidence', 'compliance'),
        _readArea(context, 'Configuration assurance', 'configuration'),
        _readArea(
          context,
          'Snapshots, releases, and change approvals',
          'lifecycle',
        ),
        _writeArea(context),
        if (_data.containsKey('lastWrite'))
          _jsonCard(context, 'Last write response', _data['lastWrite']!),
      ],
    );
  }

  Widget _errorBanner() => Padding(
    padding: const EdgeInsets.only(top: 12),
    child: Text(_error!, style: const TextStyle(color: Colors.redAccent)),
  );

  Widget _readArea(BuildContext context, String title, String section) {
    final available = governanceReadSpecs
        .where((spec) => spec.section == section && _has('GET', spec.path))
        .toList();
    return _section(context, title, [
      if (available.isEmpty)
        const Text('This feature is not enabled on the connected replica.'),
      if (available.isNotEmpty)
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: available
              .map(
                (spec) => OutlinedButton.icon(
                  onPressed: _loading ? null : () => _read(spec),
                  icon: const Icon(Icons.refresh, size: 18),
                  label: Text('Refresh ${spec.title}'),
                ),
              )
              .toList(growable: false),
        ),
      for (final spec in available)
        if (_data.containsKey(spec.key))
          _jsonCard(context, spec.title, _data[spec.key]!),
    ]);
  }

  Widget _auditArea(BuildContext context) => _section(
    context,
    'Audit investigation',
    [
      if (!_has('GET', _auditPath))
        const Text('Audit querying is not enabled on the connected replica.'),
      if (_has('GET', _auditPath)) ...[
        TextField(
          controller: _auditQuery,
          maxLines: 3,
          enabled: !_loading,
          style: _code,
          decoration: const InputDecoration(
            labelText: 'Audit filter JSON',
            helperText:
                'Example: {"tenant_id":"acme","outcome":"failure","limit":100}',
          ),
        ),
        const SizedBox(height: 8),
        FilledButton.icon(
          onPressed: _loading ? null : _queryAudit,
          icon: const Icon(Icons.manage_search),
          label: const Text('Query audit events'),
        ),
        if (_data.containsKey('audit')) _auditResults(context),
        if (_data.containsKey('facets'))
          _jsonCard(context, 'Matching audit facets', _data['facets']!),
      ],
    ],
  );

  Widget _auditResults(BuildContext context) {
    final result = _data['audit']!;
    final events = _maps(result['events']);
    return _card('Audit results (${result['count'] ?? events.length})', [
      if (events.isEmpty) const Text('No matching events.'),
      for (final event in events.take(20))
        ListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          title: Text(
            event['type']?.toString() ?? event['id']?.toString() ?? 'Event',
          ),
          subtitle: Text(
            '${event['timestamp'] ?? event['created_at'] ?? ''} ${event['outcome'] ?? ''}'
                .trim(),
          ),
        ),
      if (events.length > 20)
        Text(
          '${events.length - 20} more results are present in the copied JSON.',
        ),
      _copy(result),
    ]);
  }

  Widget _writeArea(BuildContext context) {
    final available = governanceWriteOperations
        .where((op) => _has(op.method, op.path))
        .toList();
    if (available.isEmpty) return const SizedBox.shrink();
    final selected = available.contains(_op) ? _op : available.first;
    if (_op != selected) _op = selected;
    return _section(context, 'Governed write composer', [
      const Text(
        'Use this for snapshots, deployments, disaster recovery, retention, and two-person change control.',
      ),
      const SizedBox(height: 8),
      DropdownButtonFormField<GovernanceWriteOperation>(
        initialValue: selected,
        isExpanded: true,
        decoration: const InputDecoration(labelText: 'Operation'),
        items: available
            .map(
              (item) => DropdownMenuItem(value: item, child: Text(item.label)),
            )
            .toList(),
        onChanged: _writing
            ? null
            : (value) => setState(() {
                _op = value!;
                _resourceId.clear();
                _writeBody.text = value.example;
                _confirm.clear();
              }),
      ),
      if (selected.path.contains(':id')) ...[
        const SizedBox(height: 10),
        TextField(
          controller: _resourceId,
          decoration: const InputDecoration(labelText: 'Resource ID'),
        ),
      ],
      const SizedBox(height: 10),
      TextField(
        controller: _writeBody,
        maxLines: 6,
        enabled: !_writing,
        style: _code,
        decoration: const InputDecoration(labelText: 'Request JSON'),
      ),
      const SizedBox(height: 10),
      TextField(
        controller: _confirm,
        enabled: !_writing,
        decoration: const InputDecoration(
          labelText: 'Type CONFIRM to authorize this write',
        ),
      ),
      const SizedBox(height: 10),
      FilledButton.icon(
        onPressed: _writing ? null : _runWrite,
        icon: _writing
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.warning_amber),
        label: Text('Run ${selected.label}'),
      ),
    ]);
  }

  Widget _section(BuildContext context, String title, List<Widget> children) =>
      Padding(
        padding: const EdgeInsets.only(top: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            ...children,
          ],
        ),
      );

  Widget _card(String title, List<Widget> children) => Card(
    margin: const EdgeInsets.only(top: 8),
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          ...children,
        ],
      ),
    ),
  );

  Widget _jsonCard(
    BuildContext context,
    String title,
    Map<String, dynamic> data,
  ) => _card(title, [
    ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 280),
      child: SingleChildScrollView(
        child: SelectableText(
          const JsonEncoder.withIndent('  ').convert(data),
          style: _code,
        ),
      ),
    ),
    _copy(data),
  ]);

  Widget _copy(Map<String, dynamic> data) => Align(
    alignment: Alignment.centerRight,
    child: TextButton.icon(
      onPressed: () async {
        await Clipboard.setData(
          ClipboardData(text: const JsonEncoder.withIndent('  ').convert(data)),
        );
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('JSON copied.')));
        }
      },
      icon: const Icon(Icons.copy, size: 16),
      label: const Text('Copy JSON'),
    ),
  );

  List<Map<String, dynamic>> _maps(Object? value) => value is List
      ? value
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList(growable: false)
      : const [];
}

const _code = TextStyle(fontFamily: 'monospace', fontSize: 12);
