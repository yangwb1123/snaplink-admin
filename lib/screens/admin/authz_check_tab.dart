import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:sso_admin/api/snaplink_admin_api.dart';
import 'package:sso_admin/i18n/app_strings.dart';
import 'package:sso_admin/i18n/localized_text.dart';
import 'package:sso_admin/theme/app_colors.dart';
import 'package:sso_admin/widgets/admin_breadcrumb.dart';
import 'package:sso_admin/widgets/admin_list_header.dart';
import 'package:sso_admin/widgets/empty_state.dart';
import 'admin_module_groups.dart';

/// ReBAC and WASM authorization policy check tool tab.
///
/// 工作台式页面：两张互不依赖的检查卡（能力各自门控），每张卡自带
/// idle/loading/error/result 状态区，检查语义（请求构造、结果呈现）保持。
class AuthzCheckTab extends StatefulWidget {
  final SnaplinkAdminApi api;
  final SnaplinkAdminCapabilities capabilities;
  const AuthzCheckTab({
    super.key,
    required this.api,
    required this.capabilities,
  });
  @override
  State<AuthzCheckTab> createState() => _AuthzCheckTabState();
}

class _AuthzCheckTabState extends State<AuthzCheckTab> {
  static const _rebacPath = '/api/v1/admin/rebac/check';
  static const _wasmPath = '/api/v1/admin/wasmauthz/check';
  static const _hintRebac =
      '{"object":"document:42","relation":"viewer","subject":"user:alice"}';
  static const _hintWasm = '{"principal":"","action":"","resource":{}}';

  final _rebacCtrl = TextEditingController(
    text: '{"object":"","relation":"","subject":""}',
  );
  final _wasmCtrl = TextEditingController(
    text: '{"principal":"","action":"","resource":{}}',
  );
  Map<String, dynamic>? _rebacResult;
  Map<String, dynamic>? _wasmResult;
  String? _rebacError;
  String? _wasmError;
  bool _rebacLoading = false;
  bool _wasmLoading = false;
  String? _lastRan; // 'rebac' | 'wasm'：刷新时重跑最近一次检查。

  /// 模块强调色（identity 组 indigo-violet）：页内图标/刷新统一按组色上色。
  Color get _accent => adminModuleIconColor('authz-checks');
  bool get _hasRebac => widget.capabilities.has('GET', _rebacPath);
  bool get _hasWasm => widget.capabilities.has('POST', _wasmPath);
  bool get _busy => _rebacLoading || _wasmLoading;

  @override
  void dispose() {
    _rebacCtrl.dispose();
    _wasmCtrl.dispose();
    super.dispose();
  }

  Future<void> _checkRebac() async {
    setState(() {
      _rebacLoading = true;
      _rebacError = null;
      _rebacResult = null;
      _lastRan = 'rebac';
    });
    try {
      final raw = jsonDecode(_rebacCtrl.text);
      if (raw is! Map) throw const FormatException();
      final data = Map<String, dynamic>.from(raw);
      final query = <String, String>{
        for (final key in const ['object', 'relation', 'subject'])
          key: data[key]?.toString().trim() ?? '',
      };
      if (query.values.any((value) => value.isEmpty)) {
        throw const FormatException();
      }
      final result = await widget.api.get(_rebacPath, query: query);
      if (!mounted) return;
      setState(() {
        _rebacResult = result;
        _rebacLoading = false;
      });
    } on SnaplinkAdminApiError catch (e) {
      if (mounted) {
        setState(() {
          _rebacError = e.toString();
          _rebacLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _rebacError = 'Invalid JSON or request failed.';
          _rebacLoading = false;
        });
      }
    }
  }

  Future<void> _checkWasm() async {
    setState(() {
      _wasmLoading = true;
      _wasmError = null;
      _wasmResult = null;
      _lastRan = 'wasm';
    });
    try {
      final data = jsonDecode(_wasmCtrl.text);
      final result = await widget.api.post(
        _wasmPath,
        data as Map<String, dynamic>,
      );
      if (!mounted) return;
      setState(() {
        _wasmResult = result;
        _wasmLoading = false;
      });
    } on SnaplinkAdminApiError catch (e) {
      if (mounted) {
        setState(() {
          _wasmError = e.toString();
          _wasmLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _wasmError = 'Invalid JSON or request failed.';
          _wasmLoading = false;
        });
      }
    }
  }

  /// 表单页没有后台数据可重载：刷新 = 重跑最近一次授权检查。
  void _refresh() {
    if (_lastRan == 'wasm' && _hasWasm) {
      _checkWasm();
    } else if (_lastRan == 'rebac' && _hasRebac) {
      _checkRebac();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_hasRebac && !_hasWasm) {
      return const EmptyState(
        variant: EmptyStateVariant.notEnabled,
        title: 'Authorization check tools are not enabled on this replica.',
      );
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const AdminBreadcrumb(),
        AdminListHeader(
          title: AppStrings.of(context).authzChecks,
          subtitle: 'Test ReBAC and WASM authorization policies.',
          onRefresh: _refresh,
          actions: [
            IconButton(
              onPressed: _lastRan == null || _busy ? null : _refresh,
              icon: Icon(Icons.refresh, color: _accent),
              tooltip: context.strings.refresh,
            ),
          ],
        ),
        if (_hasRebac) ...[
          _CheckCard(
            title: 'ReBAC policy check',
            icon: Icons.account_tree_outlined,
            accent: _accent,
            controller: _rebacCtrl,
            label: 'Check parameters',
            hint: _hintRebac,
            buttonLabel: 'Check ReBAC',
            loading: _rebacLoading,
            error: _rebacError,
            result: _rebacResult,
            onCheck: _checkRebac,
          ),
          const SizedBox(height: 16),
        ],
        if (_hasWasm)
          _CheckCard(
            title: 'WASM authorization check',
            icon: Icons.memory,
            accent: _accent,
            controller: _wasmCtrl,
            label: 'Request JSON',
            hint: _hintWasm,
            buttonLabel: 'Check WASM',
            loading: _wasmLoading,
            error: _wasmError,
            result: _wasmResult,
            onCheck: _checkWasm,
          ),
      ],
    );
  }
}

/// 单张授权检查卡：请求 JSON 输入 → 触发按钮 → 状态区
/// （loading 进度条 / error+重试 / 结果 JSON / 未运行时空槽）。
class _CheckCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color accent;
  final TextEditingController controller;
  final String label;
  final String hint;
  final String buttonLabel;
  final bool loading;
  final String? error;
  final Map<String, dynamic>? result;
  final VoidCallback onCheck;

  const _CheckCard({
    required this.title,
    required this.icon,
    required this.accent,
    required this.controller,
    required this.label,
    required this.hint,
    required this.buttonLabel,
    required this.loading,
    required this.error,
    required this.result,
    required this.onCheck,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: accent),
                const SizedBox(width: 8),
                LocalizedText(
                  title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: controller,
              maxLines: 4,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              decoration: InputDecoration(
                labelText: label.localized,
                hintText: hint.localized,
                prefixIcon: Icon(Icons.code, size: 18, color: accent),
              ),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.icon(
                onPressed: loading ? null : onCheck,
                icon: loading
                    ? const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.play_arrow, size: 18),
                label: LocalizedText(buttonLabel),
              ),
            ),
            const SizedBox(height: 12),
            if (loading)
              const LinearProgressIndicator(minHeight: 2)
            else
              _statusArea(context),
          ],
        ),
      ),
    );
  }

  /// 状态区：error（+重试）→ 结果 JSON → 未运行空槽。
  Widget _statusArea(BuildContext context) {
    final message = error;
    if (message != null) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, size: 18, color: AppColors.danger),
          const SizedBox(width: 8),
          Expanded(
            child: LocalizedText(
              message,
              style: const TextStyle(color: AppColors.danger),
            ),
          ),
          TextButton(
            onPressed: onCheck,
            child: const LocalizedText('Retry'),
          ),
        ],
      );
    }
    final data = result;
    if (data != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const LocalizedText(
            'Result:',
            style: TextStyle(fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(8),
            ),
            child: SelectableText(
              const JsonEncoder.withIndent('  ').convert(data),
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
          ),
        ],
      );
    }
    return Row(
      children: [
        Icon(Icons.inbox_outlined, size: 16, color: Colors.grey.shade500),
        const SizedBox(width: 8),
        LocalizedText(
          'Run a check to see the decision.',
          style: TextStyle(color: Colors.grey.shade500),
        ),
      ],
    );
  }
}
