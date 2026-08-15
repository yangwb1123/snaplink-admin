import 'package:flutter/material.dart';
import 'package:sso_admin/i18n/localized_text.dart';
import 'package:sso_admin/api/snaplink_admin_api.dart';
import 'package:sso_admin/widgets/admin_breadcrumb.dart';
import 'package:sso_admin/widgets/async_view.dart';
import 'package:sso_admin/widgets/admin_list_header.dart';
import 'package:sso_admin/widgets/empty_state.dart';
import 'package:sso_admin/i18n/app_strings.dart';
import 'package:sso_admin/widgets/section_header.dart';
import 'package:sso_admin/widgets/skeleton_list.dart';
import 'admin_module_groups.dart';
import 'admin_navigation.dart';

/// Token exchange chain audit view tab.
///
/// 只读工作台：输入 token JTI → GET /api/v1/admin/tokenexchange/chains/{jti}
/// → 返回交换链（chains/chain 双键 + 单对象回退），按跳次顺序渲染每一跳的
/// subject/actor/源目标 jti/grant_type/scopes/client_id/时间戳。语义保持
/// 与旧版一致：字段别名回退、scopes 列表 join、空值显示 '-'。
class TokenExchangeTab extends StatefulWidget {
  final SnaplinkAdminApi api;
  final SnaplinkAdminCapabilities capabilities;
  const TokenExchangeTab({
    super.key,
    required this.api,
    required this.capabilities,
  });
  @override
  State<TokenExchangeTab> createState() => _TokenExchangeTabState();
}

class _TokenExchangeTabState extends State<TokenExchangeTab> {
  static const _chainsPrefix = '/api/v1/admin/tokenexchange/chains/';

  final _searchCtrl = TextEditingController();
  Map<String, dynamic>? _chain;
  String? _error;
  bool _loading = false;

  /// 模块强调色（security 组 rose）：页内图标/按钮统一按组色上色（X7）。
  Color get _accent => adminModuleIconColor(AdminModuleId.tokenExchange);

  bool get _available =>
      widget.capabilities.hasAnyPathPrefix('/api/v1/admin/tokenexchange') ||
      SnaplinkAdminOperationCatalog.hasDocumentedPathPrefix(
        '/api/v1/admin/tokenexchange',
      );

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final jti = _searchCtrl.text.trim();
    if (jti.isEmpty) {
      setState(() => _error = 'Enter a token ID (jti).');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
      _chain = null;
    });
    try {
      final data = await widget.api.get(
        '$_chainsPrefix${Uri.encodeComponent(jti)}',
      );
      if (!mounted) return;
      setState(() {
        _chain = data;
        _loading = false;
      });
    } on SnaplinkAdminApiError catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'Could not load exchange chain.';
          _loading = false;
        });
      }
    }
  }

  /// 交换链解析语义保持：chains 列表 > chain 列表 > 单对象（一跳）。
  List<Map<String, dynamic>> _hops(Map<String, dynamic> data) {
    final raw = data['chains'] as List? ?? data['chain'] as List? ?? [data];
    return [for (final c in raw) Map<String, dynamic>.from(c as Map)];
  }

  @override
  Widget build(BuildContext context) {
    if (!_available) {
      return const EmptyState(variant: EmptyStateVariant.notEnabled);
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const AdminBreadcrumb(),
        AdminListHeader(
          title: AppStrings.of(context).tokenExchange,
          subtitle: 'Trace token exchange chains by JTI.',
          onRefresh: _load,
          actions: [
            IconButton(
              onPressed: _loading ? null : _load,
              icon: Icon(Icons.refresh, color: _accent),
              tooltip: context.strings.refresh,
            ),
          ],
        ),
        _searchRow(context),
        if (_error != null) ErrorStateCard(message: _error!, onRetry: _load, margin: EdgeInsets.zero),
        if (_loading)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: SkeletonListTile(itemCount: 3),
          ),
        if (!_loading && _chain != null) _chainSection(context, _chain!),
      ],
    );
  }

  Widget _searchRow(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                labelText: 'Token ID (JTI)'.localized,
                hintText: 'Enter a token JTI to trace its exchange chain'
                    .localized,
                prefixIcon: Icon(Icons.key_outlined, color: _accent),
              ),
              onSubmitted: (_) => _load(),
            ),
          ),
          const SizedBox(width: 12),
          IconButton(
            onPressed: _loading ? null : _load,
            icon: Icon(Icons.search, color: _accent),
            tooltip: 'Search'.localized,
          ),
        ],
      ),
    );
  }

  /// 交换链结果区：组色图标 + SectionHeader（跳数）+ 逐跳卡片，跳间以
  /// 向下箭头连接表达链式顺序。空链 → EmptyState（X8）。
  Widget _chainSection(BuildContext context, Map<String, dynamic> data) {
    final hops = _hops(data);
    if (hops.isEmpty) {
      return const Padding(
        padding: EdgeInsets.only(top: 8),
        child: EmptyState(
          compact: true,
          variant: EmptyStateVariant.empty,
          title: 'No exchange chain found for this token.',
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(Icons.swap_horiz_outlined, size: 20, color: _accent),
            const SizedBox(width: 8),
            Expanded(
              child: SectionHeader('Exchange chain', count: hops.length),
            ),
          ],
        ),
        const SizedBox(height: 4),
        for (var i = 0; i < hops.length; i++) ...[
          if (i > 0) const _ChainConnector(),
          _hopCard(context, hops[i], index: i + 1),
        ],
      ],
    );
  }

  /// 单跳卡片：跳次编号（组色 token 图标）+ 字段明细行。字段值来自 API，
  /// 走 SelectableText（可复制），标签走 context.tr（X1/X10 合规）。
  Widget _hopCard(
    BuildContext context,
    Map<String, dynamic> entry, {
    required int index,
  }) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(top: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.token_outlined, size: 16, color: _accent),
                const SizedBox(width: 8),
                Text(
                  context.tr('Hop {index}', {'index': index}),
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _row(context, 'Subject', _pick(entry, ['subject', 'sub'])),
            _row(context, 'Actor', _pick(entry, ['actor', 'actor_id'])),
            _row(context, 'Source Token', _pick(entry, ['source_jti'])),
            _row(
              context,
              'Target Token',
              _pick(entry, ['target_jti', 'jti']),
            ),
            _row(context, 'Grant Type', _pick(entry, ['grant_type'])),
            _row(context, 'Scope', _scope(entry)),
            _row(context, 'Client', _pick(entry, ['client_id'])),
            _row(
              context,
              'Timestamp',
              _pick(entry, ['timestamp', 'created_at']),
            ),
          ],
        ),
      ),
    );
  }

  /// 字段行：可翻译标签（冒号后缀仅用于展示，翻译键不含冒号）+ 等宽值。
  Widget _row(BuildContext context, String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(
            '${context.tr(label)}:',
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
        ),
        Expanded(
          child: SelectableText(
            value.isEmpty ? '-' : value,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
          ),
        ),
      ],
    ),
  );

  static String _pick(Map<String, dynamic> entry, List<String> keys) {
    for (final key in keys) {
      final value = entry[key];
      if (value != null) return value.toString();
    }
    return '';
  }

  static String _scope(Map<String, dynamic> entry) {
    final scopes = entry['scopes'];
    if (scopes is List) return scopes.join(', ');
    return entry['scope']?.toString() ?? '';
  }
}

/// 跳间连接符：向下箭头表达交换链的先后顺序。
class _ChainConnector extends StatelessWidget {
  const _ChainConnector();
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Icon(
        Icons.arrow_downward,
        size: 14,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    ),
  );
}

