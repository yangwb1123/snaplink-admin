import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:sso_admin/i18n/localized_text.dart';

class CommercePlanDialog extends StatefulWidget {
  const CommercePlanDialog({super.key});

  static Future<Map<String, dynamic>?> show(BuildContext context) =>
      showDialog<Map<String, dynamic>>(
        context: context,
        builder: (_) => const CommercePlanDialog(),
      );

  @override
  State<CommercePlanDialog> createState() => _CommercePlanDialogState();
}

class _CommercePlanDialogState extends State<CommercePlanDialog> {
  final _formKey = GlobalKey<FormState>();
  final _id = TextEditingController();
  final _version = TextEditingController(text: '1');
  final _name = TextEditingController();
  final _currency = TextEditingController(text: 'USD');
  final _price = TextEditingController(text: '0');
  final _graceDays = TextEditingController(text: '0');
  final _features = TextEditingController(
    text: const JsonEncoder.withIndent(
      '  ',
    ).convert({'core_sso': true, 'multi_tenant': true}),
  );
  final _limits = TextEditingController(
    text: const JsonEncoder.withIndent(' ').convert({
      'users': {'soft': 0, 'hard': 0, 'unlimited': true},
    }),
  );
  String _status = 'active';
  String _interval = 'month';
  String? _error;

  @override
  void dispose() {
    for (final controller in [
      _id,
      _version,
      _name,
      _currency,
      _price,
      _graceDays,
      _features,
      _limits,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    try {
      final features = _decodeObject(_features.text, 'Features');
      final limits = _decodeObject(_limits.text, 'Limits');
      _validateFeatures(features);
      _validateLimits(limits);
      Navigator.pop(context, {
        'id': _id.text.trim(),
        'version': int.parse(_version.text),
        'name': _name.text.trim(),
        'status': _status,
        'billing_interval': _interval,
        'price': {
          'currency': _currency.text.trim().toUpperCase(),
          'minor_units': int.parse(_price.text),
        },
        'grace_period_days': int.parse(_graceDays.text),
        'features': features,
        'limits': limits,
        'created_at': DateTime.now().toUtc().toIso8601String(),
      });
    } on FormatException catch (error) {
      setState(() => _error = error.message);
    }
  }

  Map<String, dynamic> _decodeObject(String source, String label) {
    try {
      final decoded = jsonDecode(source);
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } on FormatException {
      throw FormatException('$label must be a valid JSON object.');
    }
    throw FormatException('$label must be a valid JSON object.');
  }

  void _validateFeatures(Map<String, dynamic> features) {
    if (features.values.any((value) => value is! bool)) {
      throw const FormatException('Every feature value must be true or false.');
    }
  }

  void _validateLimits(Map<String, dynamic> limits) {
    for (final value in limits.values) {
      if (value is! Map || value['soft'] is! int || value['hard'] is! int) {
        throw const FormatException(
          'Every limit needs integer soft and hard values.',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const LocalizedText('Publish immutable plan version'),
    content: SizedBox(
      width: 680,
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _field(_id, 'Plan ID'),
              _field(_version, 'Version', integer: true, minimum: 1),
              _field(_name, 'Plan name'),
              Row(
                children: [
                  Expanded(child: _dropdownStatus()),
                  const SizedBox(width: 12),
                  Expanded(child: _dropdownInterval()),
                ],
              ),
              Row(
                children: [
                  Expanded(child: _field(_currency, 'Currency')),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _field(
                      _price,
                      'Price in minor units',
                      integer: true,
                      minimum: 0,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _field(
                      _graceDays,
                      'Grace period days',
                      integer: true,
                      minimum: 0,
                    ),
                  ),
                ],
              ),
              _jsonField(_features, 'Features JSON'),
              _jsonField(_limits, 'Limits JSON'),
              if (_error != null)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _error!,
                    style: const TextStyle(color: Colors.redAccent),
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const LocalizedText('Cancel'),
      ),
      FilledButton(
        onPressed: _submit,
        child: const LocalizedText('Publish plan'),
      ),
    ],
  );

  Widget _field(
    TextEditingController controller,
    String label, {
    bool integer = false,
    int? minimum,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextFormField(
      controller: controller,
      keyboardType: integer ? TextInputType.number : null,
      decoration: InputDecoration(
        labelText: label.localized,
        border: const OutlineInputBorder(),
      ),
      validator: (value) {
        final text = value?.trim() ?? '';
        if (text.isEmpty) return 'Required'.localized;
        if (!integer) return null;
        final parsed = int.tryParse(text);
        if (parsed == null || (minimum != null && parsed < minimum)) {
          return 'Enter a valid integer.'.localized;
        }
        return null;
      },
    ),
  );

  Widget _jsonField(TextEditingController controller, String label) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextFormField(
      controller: controller,
      minLines: 4,
      maxLines: 8,
      decoration: InputDecoration(
        labelText: label.localized,
        alignLabelWithHint: true,
        border: const OutlineInputBorder(),
      ),
    ),
  );

  Widget _dropdownStatus() => DropdownButtonFormField<String>(
    initialValue: _status,
    decoration: InputDecoration(
      labelText: 'Plan status'.localized,
      border: const OutlineInputBorder(),
    ),
    items: const ['active', 'retired']
        .map((value) => DropdownMenuItem(value: value, child: Text(value)))
        .toList(growable: false),
    onChanged: (value) => setState(() => _status = value ?? _status),
  );

  Widget _dropdownInterval() => DropdownButtonFormField<String>(
    initialValue: _interval,
    decoration: InputDecoration(
      labelText: 'Billing interval'.localized,
      border: const OutlineInputBorder(),
    ),
    items: const ['none', 'month', 'year']
        .map((value) => DropdownMenuItem(value: value, child: Text(value)))
        .toList(growable: false),
    onChanged: (value) => setState(() => _interval = value ?? _interval),
  );
}
