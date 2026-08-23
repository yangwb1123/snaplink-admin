part of 'break_glass_widgets.dart';

extension _BreakGlassRequestCardView on _BreakGlassRequestCardState {
  Widget _buildRequestCard(BuildContext context) {
    final targetController = widget.targetController;
    final reasonController = widget.reasonController;
    final scope = widget.scope;
    final requireApproval = widget.requireApproval;
    final mutating = widget.mutating;
    final accent = widget.accent;
    final formError = widget.formError;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(Icons.emergency_outlined, size: 20, color: accent),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: SectionHeader('New break-glass request'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: targetController,
                enabled: !mutating,
                decoration: InputDecoration(
                  labelText: 'Target user ID'.localized,
                  hintText: 'user@example.com'.localized,
                  helperText:
                      'An existing user account; the request targets this identity.'
                          .localized,
                ),
                validator: (value) => targetController.text.trim().isEmpty
                    ? 'Target user and reason are required.'.localized
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: reasonController,
                enabled: !mutating,
                decoration: InputDecoration(
                  labelText: 'Reason (ticket/incident ref)'.localized,
                  hintText: 'INC-12345'.localized,
                  helperText:
                      'Ticket or incident reference; required for traceability.'
                          .localized,
                ),
                maxLines: 2,
                validator: (value) =>
                    targetController.text.trim().isNotEmpty &&
                        reasonController.text.trim().isEmpty
                    ? 'Target user and reason are required.'.localized
                    : null,
              ),
              const SizedBox(height: 12),
              // R31：保持 Dropdown——Scope 三段标签（Impersonate 等）与下方
              // 授权列表的动作文案同词，SegmentedButton 常显会让既有测试的
              // find.text 语义歧义（且 grant 动作本身已是可见选择点）。
              DropdownButtonFormField<String>(
                initialValue: scope,
                // R29 字体缩放：isExpanded 约束选中项宽度，2x 下不横向溢出。
                isExpanded: true,
                decoration: InputDecoration(labelText: 'Scope'.localized),
                items: const [
                  DropdownMenuItem(
                    value: 'readonly',
                    child: LocalizedText('Read-only'),
                  ),
                  DropdownMenuItem(
                    value: 'impersonate',
                    child: LocalizedText('Impersonate'),
                  ),
                  DropdownMenuItem(
                    value: 'escalate',
                    child: LocalizedText('Escalate'),
                  ),
                ],
                onChanged: mutating
                    ? null
                    : (value) => widget.onScopeChanged(value ?? 'readonly'),
              ),
              const SizedBox(height: 12),
              TextField(
                enabled: !mutating,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  labelText: 'TTL (seconds, default 900)'.localized,
                  helperText:
                      'Session lifetime in seconds; the server enforces the maximum.'
                          .localized,
                ),
                onChanged: widget.onTtlChanged,
              ),
              // R31：二选一设置 → SwitchListTile（原 Checkbox 是开关语义，
              // Checkbox 应留给确认/多选场景）。
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const LocalizedText('Require approval'),
                value: requireApproval,
                onChanged: mutating ? null : widget.onRequireApprovalChanged,
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: mutating ? null : _submit,
                icon: mutating
                    ? const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.add, size: 18),
                label: const LocalizedText('Create break-glass request'),
              ),
              if (formError != null) ...[
                const SizedBox(height: 12),
                LocalizedText(
                  formError,
                  // R29：dark 下提亮（2.26→5.29:1 ≥AA），浅色恒等。
                  style: TextStyle(
                    color: AppColors.semanticFor(
                      Theme.of(context).brightness,
                      AppColors.danger,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
