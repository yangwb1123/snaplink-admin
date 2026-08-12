import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:sso_admin/i18n/localized_text.dart';
import 'package:sso_admin/services/sensitive_data.dart';
import 'package:sso_admin/theme/app_colors.dart';
import 'admin_module_groups.dart';
import 'admin_navigation.dart';

/// 变更审批模型 + 提议对话框。
///
/// 归一化：兼容 Go snake_case/PascalCase 字段与 base64/原始字节 payload；
/// 未解码的敏感负载一律不暴露到管理端 UI（后端规范 02/07）。
Map<String, dynamic> normalizeChangeApproval(Map<dynamic, dynamic> raw) {
  Object? field(String snake, String pascal) => raw[snake] ?? raw[pascal];

  return <String, dynamic>{
    'id': field('id', 'ID')?.toString() ?? '',
    'action_type': field('action_type', 'ActionType')?.toString() ?? '',
    'payload': _decodePayload(field('payload', 'Payload')),
    'reason': field('reason', 'Reason')?.toString() ?? '',
    'proposed_by': field('proposed_by', 'ProposedBy')?.toString() ?? '',
    'approved_by': field('approved_by', 'ApprovedBy')?.toString() ?? '',
    'status': field('status', 'Status')?.toString() ?? 'unknown',
    'failure_note': field('failure_note', 'FailureNote')?.toString() ?? '',
    'created_at': field('created_at', 'CreatedAt')?.toString() ?? '',
    'decided_at': field('decided_at', 'DecidedAt')?.toString() ?? '',
  };
}

Map<String, dynamic> _decodePayload(Object? value) {
  if (value == null) return const {};
  if (value is Map) return Map<String, dynamic>.from(value);
  if (value is List<int>) return _decodePayloadBytes(value);
  if (value is String) {
    if (value.trim().isEmpty) return const {};
    try {
      final decoded = jsonDecode(value);
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } on FormatException {
      // Go's encoding/json represents []byte as base64. Try that below.
    }
    try {
      return _decodePayloadBytes(base64Decode(value));
    } on FormatException {
      return const {'_unavailable': 'Payload could not be decoded safely.'};
    }
  }
  return const {'_unavailable': 'Payload could not be decoded safely.'};
}

Map<String, dynamic> _decodePayloadBytes(List<int> value) {
  try {
    final decoded = jsonDecode(utf8.decode(value));
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
  } on FormatException {
    // Never expose an undecodable raw/base64 payload in the admin UI.
  }
  return const {'_unavailable': 'Payload could not be decoded safely.'};
}

/// 提议草稿：action_type + reason + payload（敏感字段门禁在对话框内）。
class ChangeApprovalDraft {
  final String actionType;
  final String reason;
  final Map<String, dynamic> payload;
  const ChangeApprovalDraft({
    required this.actionType,
    required this.reason,
    required this.payload,
  });

  Map<String, dynamic> get body => {
    'action_type': actionType,
    'reason': reason,
    'payload': payload,
  };
}

/// 提议对话框：action_type / 业务理由 / payload JSON 三字段。
/// payload 必须是 JSON 对象；持久化审批载荷拒绝密码/令牌/凭据。
class ChangeApprovalProposalDialog extends StatefulWidget {
  const ChangeApprovalProposalDialog({super.key});

  @override
  State<ChangeApprovalProposalDialog> createState() =>
      _ChangeApprovalProposalDialogState();
}

class _ChangeApprovalProposalDialogState
    extends State<ChangeApprovalProposalDialog> {
  final _formKey = GlobalKey<FormState>();
  final _typeCtrl = TextEditingController();
  final _reasonCtrl = TextEditingController();
  final _payloadCtrl = TextEditingController(text: '{}');
  String? _error;
  @override
  void dispose() {
    _typeCtrl.dispose();
    _reasonCtrl.dispose();
    _payloadCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    try {
      final decoded = jsonDecode(_payloadCtrl.text);
      if (decoded is! Map) throw const FormatException();
      if (SensitiveData.containsSensitiveField(decoded)) {
        setState(
          () => _error =
              'Approval payloads are persisted. Reference a secret by ID; '
              'do not include passwords, tokens, or credentials.',
        );
        return;
      }
      Navigator.pop(
        context,
        ChangeApprovalDraft(
          actionType: _typeCtrl.text.trim(),
          reason: _reasonCtrl.text.trim(),
          payload: Map<String, dynamic>.from(decoded),
        ),
      );
    } on FormatException {
      setState(() => _error = 'Payload must be a JSON object.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = adminModuleIconColor(AdminModuleId.changeApprovals);
    return AlertDialog(
      icon: Icon(Icons.add_task_outlined, color: accent, size: 28),
      title: const LocalizedText('Propose governed change'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _typeCtrl,
                decoration: InputDecoration(
                  labelText: 'Action type'.localized,
                  helperText: 'Must match an action enabled by the server.'
                      .localized,
                ),
                validator: (value) =>
                    value?.trim().isEmpty == true ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _reasonCtrl,
                decoration: InputDecoration(
                  labelText: 'Business justification / ticket'.localized,
                ),
                maxLines: 2,
                validator: (value) =>
                    value?.trim().isEmpty == true ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _payloadCtrl,
                decoration: InputDecoration(labelText: 'Payload JSON'.localized),
                minLines: 4,
                maxLines: 8,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                LocalizedText(
                  _error!,
                  style: const TextStyle(color: AppColors.danger),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const LocalizedText('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: const LocalizedText('Propose')),
      ],
    );
  }
}
