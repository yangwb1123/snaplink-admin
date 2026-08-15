import 'package:flutter/material.dart';
import 'package:sso_admin/i18n/localized_text.dart';

import 'commerce_models.dart';

class CommerceCreateSubscriptionDialog extends StatefulWidget {
  final List<Map<String, dynamic>> plans;

  const CommerceCreateSubscriptionDialog({super.key, required this.plans});

  static Future<Map<String, dynamic>?> show(
    BuildContext context,
    List<Map<String, dynamic>> plans,
  ) => showDialog<Map<String, dynamic>>(
    context: context,
    builder: (_) => CommerceCreateSubscriptionDialog(plans: plans),
  );

  @override
  State<CommerceCreateSubscriptionDialog> createState() =>
      _CommerceCreateSubscriptionDialogState();
}

class _CommerceCreateSubscriptionDialogState
    extends State<CommerceCreateSubscriptionDialog> {
  final _formKey = GlobalKey<FormState>();
  final _trialEnd = TextEditingController();
  final _provider = TextEditingController();
  final _providerID = TextEditingController();
  late String _selected;

  List<Map<String, dynamic>> get _activePlans => widget.plans
      .where((plan) => plan['status']?.toString() == 'active')
      .toList(growable: false);

  @override
  void initState() {
    super.initState();
    _selected = _activePlans.isEmpty ? '' : _planKey(_activePlans.first);
  }

  @override
  void dispose() {
    _trialEnd.dispose();
    _provider.dispose();
    _providerID.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final plan = _activePlans.firstWhere(
      (candidate) => _planKey(candidate) == _selected,
    );
    final body = <String, dynamic>{
      'plan_id': plan['id'],
      'plan_version': plan['version'],
    };
    _putIfPresent(body, 'trial_end', _trialEnd.text);
    _putIfPresent(body, 'provider', _provider.text);
    _putIfPresent(body, 'provider_subscription_id', _providerID.text);
    Navigator.pop(context, body);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const LocalizedText('Create tenant subscription'),
    content: SizedBox(
      width: 520,
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              initialValue: _selected.isEmpty ? null : _selected,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Plan version'.localized,
                border: const OutlineInputBorder(),
              ),
              items: _activePlans
                  .map(
                    (plan) => DropdownMenuItem(
                      value: _planKey(plan),
                      child: Text(commercePlanLabel(plan)),
                    ),
                  )
                  .toList(growable: false),
              validator: (value) => value == null ? 'Required'.localized : null,
              onChanged: (value) => setState(() => _selected = value ?? ''),
            ),
            const SizedBox(height: 12),
            _field(_trialEnd, 'Trial end (optional RFC3339)'),
            _field(_provider, 'Provider identifier (optional)'),
            _field(_providerID, 'Provider subscription ID (optional)'),
            const Align(
              alignment: Alignment.centerLeft,
              child: LocalizedText(
                'Provider identifiers are references only. Never enter provider secrets or payment credentials.',
              ),
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const LocalizedText('Cancel'),
      ),
      FilledButton(
        onPressed: _activePlans.isEmpty ? null : _submit,
        child: const LocalizedText('Create subscription'),
      ),
    ],
  );

  Widget _field(TextEditingController controller, String label) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label.localized,
        border: const OutlineInputBorder(),
      ),
      validator: label.startsWith('Trial')
          ? (value) {
              final text = value?.trim() ?? '';
              if (text.isEmpty || DateTime.tryParse(text) != null) return null;
              return 'Enter a valid RFC3339 timestamp.'.localized;
            }
          : null,
    ),
  );

  static String _planKey(Map<String, dynamic> plan) =>
      '${plan['id']}@${plan['version']}';

  static void _putIfPresent(
    Map<String, dynamic> body,
    String key,
    String value,
  ) {
    final normalized = value.trim();
    if (normalized.isNotEmpty) body[key] = normalized;
  }
}

class CommercePlanChangeDialog extends StatefulWidget {
  final List<Map<String, dynamic>> plans;

  const CommercePlanChangeDialog({super.key, required this.plans});

  static Future<(String, int)?> show(
    BuildContext context,
    List<Map<String, dynamic>> plans,
  ) => showDialog<(String, int)>(
    context: context,
    builder: (_) => CommercePlanChangeDialog(plans: plans),
  );

  @override
  State<CommercePlanChangeDialog> createState() =>
      _CommercePlanChangeDialogState();
}

class _CommercePlanChangeDialogState extends State<CommercePlanChangeDialog> {
  late final List<Map<String, dynamic>> _plans;
  String? _selected;

  @override
  void initState() {
    super.initState();
    _plans = widget.plans
        .where((plan) => plan['status']?.toString() == 'active')
        .toList(growable: false);
    _selected = _plans.isEmpty ? null : _key(_plans.first);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const LocalizedText('Change subscription plan'),
    content: DropdownButtonFormField<String>(
      initialValue: _selected,
      autofocus: true,
      decoration: InputDecoration(
        labelText: 'New plan version'.localized,
        border: const OutlineInputBorder(),
      ),
      items: _plans
          .map(
            (plan) => DropdownMenuItem(
              value: _key(plan),
              child: Text(commercePlanLabel(plan)),
            ),
          )
          .toList(growable: false),
      onChanged: (value) => setState(() => _selected = value),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const LocalizedText('Cancel'),
      ),
      FilledButton(
        onPressed: _selected == null ? null : _submit,
        child: const LocalizedText('Change plan'),
      ),
    ],
  );

  void _submit() {
    final plan = _plans.firstWhere((candidate) => _key(candidate) == _selected);
    Navigator.pop(context, (plan['id'].toString(), plan['version'] as int));
  }

  static String _key(Map<String, dynamic> plan) =>
      '${plan['id']}@${plan['version']}';
}

class CommerceStatusDialog extends StatefulWidget {
  final String current;

  const CommerceStatusDialog({super.key, required this.current});

  static Future<String?> show(BuildContext context, String current) =>
      showDialog<String>(
        context: context,
        builder: (_) => CommerceStatusDialog(current: current),
      );

  @override
  State<CommerceStatusDialog> createState() => _CommerceStatusDialogState();
}

class _CommerceStatusDialogState extends State<CommerceStatusDialog> {
  late String _status = widget.current;

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const LocalizedText('Transition subscription status'),
    content: DropdownButtonFormField<String>(
      initialValue: _status,
      autofocus: true,
      decoration: InputDecoration(
        labelText: 'New status'.localized,
        border: const OutlineInputBorder(),
      ),
      items:
          const [
                'pending',
                'trialing',
                'active',
                'past_due',
                'paused',
                'canceled',
                'expired',
              ]
              .map(
                (value) => DropdownMenuItem(value: value, child: Text(value)),
              )
              .toList(growable: false),
      onChanged: (value) => setState(() => _status = value ?? _status),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const LocalizedText('Cancel'),
      ),
      FilledButton(
        onPressed: _status == widget.current
            ? null
            : () => Navigator.pop(context, _status),
        child: const LocalizedText('Apply transition'),
      ),
    ],
  );
}
