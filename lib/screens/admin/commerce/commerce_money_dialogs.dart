import 'package:flutter/material.dart';
import 'package:sso_admin/i18n/localized_text.dart';

import 'commerce_models.dart';

class CommerceWalletAdjustmentDialog extends StatefulWidget {
  final String currency;

  const CommerceWalletAdjustmentDialog({super.key, required this.currency});

  static Future<Map<String, dynamic>?> show(
    BuildContext context,
    String currency,
  ) => showDialog<Map<String, dynamic>>(
    context: context,
    builder: (_) => CommerceWalletAdjustmentDialog(currency: currency),
  );

  @override
  State<CommerceWalletAdjustmentDialog> createState() =>
      _CommerceWalletAdjustmentDialogState();
}

class _CommerceWalletAdjustmentDialogState
    extends State<CommerceWalletAdjustmentDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _currency = TextEditingController(text: widget.currency);
  final _amount = TextEditingController();
  final _reference = TextEditingController();
  final _idempotency = TextEditingController(
    text: commerceIdempotencyKey('adjustment'),
  );

  @override
  void dispose() {
    _currency.dispose();
    _amount.dispose();
    _reference.dispose();
    _idempotency.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(context, {
      'currency': _currency.text.trim().toUpperCase(),
      'amount_minor': int.parse(_amount.text),
      'reference': _reference.text.trim(),
      'idempotency_key': _idempotency.text.trim(),
    });
  }

  @override
  Widget build(BuildContext context) => _MoneyDialogFrame(
    title: 'Post wallet adjustment',
    submitLabel: 'Post adjustment',
    onSubmit: _submit,
    child: Form(
      key: _formKey,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _currencyField(_currency),
          _integerField(
            _amount,
            'Signed amount in minor units',
            allowNegative: true,
            rejectZero: true,
          ),
          _requiredField(_reference, 'Audit reference'),
          _requiredField(_idempotency, 'Idempotency key'),
          const LocalizedText(
            'Adjustments are immutable ledger entries. Use a ticket or incident reference and reuse the same idempotency key after an unknown response.',
          ),
        ],
      ),
    ),
  );
}

class CommerceTopUpDialog extends StatefulWidget {
  final String currency;

  const CommerceTopUpDialog({super.key, required this.currency});

  static Future<Map<String, dynamic>?> show(
    BuildContext context,
    String currency,
  ) => showDialog<Map<String, dynamic>>(
    context: context,
    builder: (_) => CommerceTopUpDialog(currency: currency),
  );

  @override
  State<CommerceTopUpDialog> createState() => _CommerceTopUpDialogState();
}

class _CommerceTopUpDialogState extends State<CommerceTopUpDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _currency = TextEditingController(text: widget.currency);
  final _amount = TextEditingController();
  final _idempotency = TextEditingController(
    text: commerceIdempotencyKey('top-up'),
  );

  @override
  void dispose() {
    _currency.dispose();
    _amount.dispose();
    _idempotency.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(context, <String, dynamic>{
      'currency': _currency.text.trim().toUpperCase(),
      'amount_minor': int.parse(_amount.text),
      'idempotency_key': _idempotency.text.trim(),
    });
  }

  @override
  Widget build(BuildContext context) => _MoneyDialogFrame(
    title: 'Create Stripe top-up',
    submitLabel: 'Continue to secure checkout',
    onSubmit: _submit,
    child: Form(
      key: _formKey,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _currencyField(_currency),
          _integerField(_amount, 'Top-up amount in minor units', minimum: 1),
          _requiredField(_idempotency, 'Idempotency key'),
          const LocalizedText(
            'The console creates a pending Stripe order, then opens the separate secure checkout page. Card data, API keys and provider signatures never enter this console.',
          ),
        ],
      ),
    ),
  );
}

class _MoneyDialogFrame extends StatelessWidget {
  final String title;
  final String submitLabel;
  final VoidCallback onSubmit;
  final Widget child;

  const _MoneyDialogFrame({
    required this.title,
    required this.submitLabel,
    required this.onSubmit,
    required this.child,
  });

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: LocalizedText(title),
    content: SizedBox(width: 520, child: child),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const LocalizedText('Cancel'),
      ),
      FilledButton(onPressed: onSubmit, child: LocalizedText(submitLabel)),
    ],
  );
}

Widget _requiredField(TextEditingController controller, String label) =>
    Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label.localized,
          border: const OutlineInputBorder(),
        ),
        validator: (value) =>
            value?.trim().isEmpty ?? true ? 'Required'.localized : null,
      ),
    );

Widget _currencyField(TextEditingController controller) => Padding(
  padding: const EdgeInsets.only(bottom: 12),
  child: TextFormField(
    controller: controller,
    autofocus: true,
    textCapitalization: TextCapitalization.characters,
    decoration: InputDecoration(
      labelText: 'Currency'.localized,
      border: const OutlineInputBorder(),
    ),
    validator: (value) => RegExp(r'^[A-Za-z]{3}$').hasMatch(value?.trim() ?? '')
        ? null
        : 'Use a three-letter currency code.'.localized,
  ),
);

Widget _integerField(
  TextEditingController controller,
  String label, {
  int? minimum,
  bool allowNegative = false,
  bool rejectZero = false,
}) => Padding(
  padding: const EdgeInsets.only(bottom: 12),
  child: TextFormField(
    controller: controller,
    keyboardType: TextInputType.numberWithOptions(signed: allowNegative),
    decoration: InputDecoration(
      labelText: label.localized,
      border: const OutlineInputBorder(),
    ),
    validator: (value) {
      final parsed = int.tryParse(value?.trim() ?? '');
      if (parsed == null || (minimum != null && parsed < minimum)) {
        return 'Enter a valid integer.'.localized;
      }
      if (rejectZero && parsed == 0) return 'Amount cannot be zero.'.localized;
      return null;
    },
  ),
);
