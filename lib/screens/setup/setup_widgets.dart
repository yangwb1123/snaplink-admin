import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class SetupLoadingPanel extends StatelessWidget {
  const SetupLoadingPanel({super.key});

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      const SetupLogo(),
      const SizedBox(height: 12),
      Text(
        'Setup',
        style: Theme.of(context).textTheme.titleLarge,
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 6),
      Text(
        'Checking system status…',
        style: Theme.of(context).textTheme.bodySmall,
        textAlign: TextAlign.center,
      ),
    ],
  );
}

class SetupAlreadyInitializedPanel extends StatelessWidget {
  final VoidCallback onContinue;

  const SetupAlreadyInitializedPanel({super.key, required this.onContinue});

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const SetupLogo(),
      const SizedBox(height: 12),
      Text(
        'Already set up',
        style: Theme.of(context).textTheme.titleLarge,
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 14),
      const SetupSuccessBox(text: 'This system has already been initialized.'),
      const SizedBox(height: 6),
      FilledButton(
        onPressed: onContinue,
        child: const Text('Go to admin console'),
      ),
    ],
  );
}

class SetupUnavailablePanel extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  final VoidCallback onContinue;

  const SetupUnavailablePanel({
    super.key,
    required this.message,
    required this.onRetry,
    required this.onContinue,
  });

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const SetupLogo(),
      const SizedBox(height: 12),
      Text(
        'Setup unavailable',
        style: Theme.of(context).textTheme.titleLarge,
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 14),
      SetupErrorBox(text: message),
      const SizedBox(height: 12),
      OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
      const SizedBox(height: 8),
      FilledButton(
        onPressed: onContinue,
        child: const Text('Go to admin console'),
      ),
    ],
  );
}

class SetupLogo extends StatelessWidget {
  const SetupLogo({super.key});
  @override
  Widget build(BuildContext context) => Container(
    width: 44,
    height: 44,
    decoration: BoxDecoration(
      color: const Color(0xFF6366F1),
      borderRadius: BorderRadius.circular(10),
    ),
    child: const Icon(Icons.vpn_key, color: Colors.white, size: 24),
  );
}

class SetupStepDots extends StatelessWidget {
  final int activeCount;
  const SetupStepDots({super.key, required this.activeCount});
  @override
  Widget build(BuildContext context) {
    Widget dot(bool on) => Container(
      width: 34,
      height: 4,
      decoration: BoxDecoration(
        color: on ? const Color(0xFF6366F1) : const Color(0xFF334155),
        borderRadius: BorderRadius.circular(3),
      ),
    );
    return Semantics(
      label: 'Step $activeCount of 2',
      child: ExcludeSemantics(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            dot(activeCount >= 1),
            const SizedBox(width: 8),
            dot(activeCount >= 2),
          ],
        ),
      ),
    );
  }
}

class SetupOptionalTag extends StatelessWidget {
  const SetupOptionalTag({super.key});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
    decoration: BoxDecoration(
      color: const Color(0xFF3730A3),
      borderRadius: BorderRadius.circular(6),
    ),
    child: const Text(
      'optional',
      style: TextStyle(color: Color(0xFFC7D2FE), fontSize: 11),
    ),
  );
}

class SetupErrorBox extends StatelessWidget {
  final String text;
  const SetupErrorBox({super.key, required this.text});
  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF7F1D1D),
        border: Border.all(color: const Color(0xFFB91C1C)),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Text(
        text,
        style: const TextStyle(color: Color(0xFFFECACA), fontSize: 13),
      ),
    ),
  );
}

class SetupSuccessBox extends StatelessWidget {
  final String text;
  const SetupSuccessBox({super.key, required this.text});
  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF064E3B),
        border: Border.all(color: const Color(0xFF059669)),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Text(
        text,
        style: const TextStyle(color: Color(0xFFA7F3D0), fontSize: 14),
      ),
    ),
  );
}

class SetupCredBox extends StatelessWidget {
  final Widget child;
  const SetupCredBox({super.key, required this.child});
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    decoration: BoxDecoration(
      color: const Color(0xFF0F172A),
      border: Border.all(color: const Color(0xFF334155)),
      borderRadius: BorderRadius.circular(9),
    ),
    child: child,
  );
}

class SetupCredentialValue extends StatelessWidget {
  final String label;
  final String value;
  final bool shownOnce;

  const SetupCredentialValue({
    super.key,
    required this.label,
    required this.value,
    this.shownOnce = false,
  });

  Future<void> _copy(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$label copied.')));
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        children: [
          Expanded(
            child: Text(
              shownOnce ? '$label · shown once' : label,
              style: Theme.of(context).textTheme.labelLarge,
            ),
          ),
          IconButton(
            tooltip: 'Copy $label',
            onPressed: () => _copy(context),
            icon: const Icon(Icons.copy_outlined, size: 19),
          ),
        ],
      ),
      SetupCredBox(
        child: SelectableText(
          value,
          style: const TextStyle(fontFamily: 'monospace'),
        ),
      ),
    ],
  );
}

class SetupDonePanel extends StatefulWidget {
  final String? adminUsername;
  final String? clientId;
  final String? clientSecret;
  final bool applicationRequestedButMissing;
  final VoidCallback onDone;
  const SetupDonePanel({
    super.key,
    this.adminUsername,
    this.clientId,
    this.clientSecret,
    this.applicationRequestedButMissing = false,
    required this.onDone,
  });

  @override
  State<SetupDonePanel> createState() => _SetupDonePanelState();
}

class _SetupDonePanelState extends State<SetupDonePanel> {
  bool _savedSecret = false;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const Icon(Icons.check_circle_outline, size: 72, color: Colors.green),
      const SizedBox(height: 16),
      Text('Setup complete', style: Theme.of(context).textTheme.headlineMedium),
      const SizedBox(height: 8),
      const Text(
        'Your single sign-on server is ready. These credentials will not be shown again.',
      ),
      if (widget.adminUsername != null) ...[
        const SizedBox(height: 8),
        SetupCredentialValue(
          label: 'Administrator username',
          value: widget.adminUsername!,
        ),
      ],
      if (widget.applicationRequestedButMissing) ...[
        const SizedBox(height: 12),
        const SetupErrorBox(
          text:
              'The administrator was created, but Snaplink could not create the optional application. Sign in and register it from Clients.',
        ),
      ],
      if (widget.clientId != null) ...[
        const SizedBox(height: 8),
        SetupCredentialValue(label: 'Client ID', value: widget.clientId!),
      ],
      if (widget.clientSecret != null) ...[
        const SizedBox(height: 8),
        SetupCredentialValue(
          label: 'Client secret',
          value: widget.clientSecret!,
          shownOnce: true,
        ),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          value: _savedSecret,
          onChanged: (value) => setState(() => _savedSecret = value ?? false),
          title: const Text('I have securely saved the client secret.'),
          subtitle: const Text(
            'Leaving setup permanently erases this one-time display.',
          ),
        ),
      ],
      const SizedBox(height: 32),
      FilledButton(
        onPressed: widget.clientSecret == null || _savedSecret
            ? widget.onDone
            : null,
        child: const Text('Go to admin console'),
      ),
    ],
  );
}
