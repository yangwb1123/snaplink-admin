import 'package:flutter/material.dart';
import 'package:sso_admin/api/snaplink_admin_api.dart';
import 'package:sso_admin/widgets/admin_data_table.dart';
import 'package:sso_admin/i18n/localized_text.dart';
import 'package:sso_admin/theme/app_colors.dart';

/// 平台审计时间线：读取 snaplink 审计账本（/api/v1/audit/events）。
/// 显示时间、事件类型（可读化）、操作人、IP、结果与关联元数据。
class PlatformAuditView extends StatefulWidget {
  final SnaplinkAdminApi api;
  const PlatformAuditView({super.key, required this.api});

  @override
  State<PlatformAuditView> createState() => _PlatformAuditViewState();
}

/// 事件类型 → 人类可读标签（snaplink platform/audit event_types）。
const Map<String, String> kAuditTypeLabels = {
  'login': '登录',
  'login_failure': '登录失败',
  'new_device_login': '新设备登录',
  'new_location_login': '新地点登录',
  'trust_decay': '信任衰减',
  'logout': '登出',
  'token_issued': '令牌签发',
  'token_revoked': '令牌吊销',
  'code_sent': '验证码发送',
  'callback_failure': '回调失败',
  'client_access': '客户端访问',
  'permission_query': '权限查询',
  'client_registered': '客户端注册',
  'client_updated': '客户端更新',
  'client_deleted': '客户端删除',
  'netpolicy_apply': '网络策略生效',
  'netpolicy_delete': '网络策略删除',
  'logout_notified': '登出通知',
  'partial_revoke_failure': '部分吊销失败',
  'tenant_tokens_revoked': '租户令牌吊销',
  'tenant_sessions_revoked': '租户会话吊销',
  'account_locked': '账号锁定',
  'mfa_required': 'MFA 要求',
};

class _PlatformAuditViewState extends State<PlatformAuditView> {
  List<PlatformAuditEvent> _events = [];
  String? _error;
  bool _loading = true;
  String _typeFilter = 'ALL';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final events = await widget.api.fetchPlatformAuditEvents(
        type: _typeFilter == 'ALL' ? null : _typeFilter,
        limit: 200,
      );
      if (mounted) setState(() => _events = events);
    } catch (cause) {
      if (mounted) {
        setState(() => _error = cause.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _formatTime(DateTime? ts) {
    if (ts == null) return '-';
    final local = ts.toLocal();
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    final ss = local.second.toString().padLeft(2, '0');
    return '${local.year}-${local.month.toString().padLeft(2, '0')}-'
        '${local.day.toString().padLeft(2, '0')} $hh:$mm:$ss';
  }

  String _typeLabel(String type) => kAuditTypeLabels[type] ?? type;

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(40),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.error_outline, color: AppColors.danger),
            const SizedBox(height: 8),
            const LocalizedText('无法读取平台审计账本'),
            const SizedBox(height: 4),
            Text(
              _error!,
              style: const TextStyle(color: AppColors.muted, fontSize: 13),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh, size: 16),
              label: const LocalizedText('重试'),
            ),
          ],
        ),
      );
    }
    if (_events.isEmpty) {
      return const Padding(
        padding: EdgeInsets.only(top: 40),
        child: Center(
          child: LocalizedText('账本暂无事件（需审计 api_enabled: true）'),
        ),
      );
    }
    final types = _events.map((e) => e.type).toSet().toList()..sort();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Wrap(
            spacing: 8,
            children: [
              _filterChip('ALL', '全部'),
              for (final type in types) _filterChip(type, _typeLabel(type)),
            ],
          ),
        ),
        AdminDataTable(
          minWidth: 1000,
          itemCount: _events.length,
          rowBuilder: (context, i) => const SizedBox.shrink(),
          columns: [
            AdminDataColumn(
              id: 'time',
              label: 'TIME',
              width: 160,
              builder: (context, i) => TableCellText(
                _formatTime(_events[i].timestamp),
                muted: true,
              ),
            ),
            AdminDataColumn(
              id: 'type',
              label: 'EVENT',
              width: 140,
              builder: (context, i) {
                final type = _events[i].type;
                final isBad = type.contains('failure') ||
                    type.contains('revoke_failure') ||
                    type.contains('locked');
                return TableCellText(
                  _typeLabel(type),
                  bold: true,
                  color: isBad ? AppColors.danger : null,
                );
              },
            ),
            AdminDataColumn(
              id: 'outcome',
              label: 'RESULT',
              width: 90,
              builder: (context, i) => TableCellText(
                _events[i].outcome,
                color: _events[i].outcome == 'success'
                    ? AppColors.success
                    : AppColors.danger,
                bold: true,
              ),
            ),
            AdminDataColumn(
              id: 'actor',
              label: 'ACTOR',
              width: 120,
              builder: (context, i) =>
                  TableCellText(_events[i].actorId.isEmpty ? '-' : _events[i].actorId),
            ),
            AdminDataColumn(
              id: 'ip',
              label: 'IP',
              width: 120,
              builder: (context, i) =>
                  TableCellText(_events[i].actorIp.isEmpty ? '-' : _events[i].actorIp),
            ),
            AdminDataColumn(
              id: 'detail',
              label: 'DETAIL',
              builder: (context, i) {
                final e = _events[i];
                final meta = e.metadata.entries.map((m) => '${m.key}=${m.value}').join(' ');
                final detail = [
                  if (e.clientId.isNotEmpty) 'client=${e.clientId}',
                  if (e.reason.isNotEmpty) 'reason=${e.reason}',
                  if (meta.isNotEmpty) meta,
                ].join(' ');
                return TableCellText(
                  detail.isEmpty ? '-' : detail,
                  muted: true,
                  maxLines: 2,
                );
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _filterChip(String value, String label) {
    final selected = _typeFilter == value;
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) {
        setState(() => _typeFilter = value);
        _load();
      },
      visualDensity: VisualDensity.compact,
    );
  }
}
