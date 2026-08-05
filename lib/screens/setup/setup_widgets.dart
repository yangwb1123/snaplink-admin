import 'package:flutter/material.dart';
import 'package:sso_admin/theme/app_colors.dart';
import 'package:flutter/services.dart';
import '../../i18n/app_strings.dart';

class SetupLoadingPanel extends StatelessWidget {
  const SetupLoadingPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SetupLogo(),
        const SizedBox(height: 12),
        Text(
          strings.setup,
          style: Theme.of(context).textTheme.titleLarge,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          strings.checkingSystemStatus,
          style: Theme.of(context).textTheme.bodySmall,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class SetupAlreadyInitializedPanel extends StatelessWidget {
  final VoidCallback onContinue;

  const SetupAlreadyInitializedPanel({super.key, required this.onContinue});

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SetupLogo(),
        const SizedBox(height: 12),
        Text(
          strings.alreadySetUp,
          style: Theme.of(context).textTheme.titleLarge,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        SetupSuccessBox(text: strings.alreadyInitialized),
        const SizedBox(height: 8),
        FilledButton(
          onPressed: onContinue,
          child: Text(strings.goToAdminConsole),
        ),
      ],
    );
  }
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
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SetupLogo(),
        const SizedBox(height: 12),
        Text(
          strings.setupUnavailableTitle,
          style: Theme.of(context).textTheme.titleLarge,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        SetupErrorBox(text: message),
        const SizedBox(height: 12),
        OutlinedButton(onPressed: onRetry, child: Text(strings.retry)),
        const SizedBox(height: 8),
        FilledButton(
          onPressed: onContinue,
          child: Text(strings.goToAdminConsole),
        ),
      ],
    );
  }
}

class SetupLogo extends StatelessWidget {
  const SetupLogo({super.key});
  @override
  Widget build(BuildContext context) => Container(
    width: 44,
    height: 44,
    decoration: BoxDecoration(
      color: AppColors.primary,
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
        color: on ? AppColors.primary : AppColors.textSubtle,
        borderRadius: BorderRadius.circular(3),
      ),
    );
    return Semantics(
      label: AppStrings.of(context).stepOf(activeCount, 2),
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
  final String label;
  const SetupOptionalTag({super.key, required this.label});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
    decoration: BoxDecoration(
      color: AppColors.primaryDark,
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text(
      label,
      style: const TextStyle(color: AppColors.primaryTint, fontSize: 11),
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.dangerDark,
        border: Border.all(color: AppColors.danger),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Text(
        text,
        style: const TextStyle(color: AppColors.dangerTint, fontSize: 13),
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.successDark,
        border: Border.all(color: AppColors.success),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Text(
        text,
        style: const TextStyle(color: AppColors.successTint, fontSize: 14),
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
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    decoration: BoxDecoration(
      color: AppColors.textStrong,
      border: Border.all(color: AppColors.textSubtle),
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppStrings.of(context).copiedLabel(label))),
    );
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        children: [
          Expanded(
            child: Text(
              shownOnce ? AppStrings.of(context).shownOnce(label) : label,
              style: Theme.of(context).textTheme.labelLarge,
            ),
          ),
          IconButton(
            tooltip: AppStrings.of(context).copyLabel(label),
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
  final Future<void> Function()? onRetryApplication;
  final VoidCallback onDone;
  const SetupDonePanel({
    super.key,
    this.adminUsername,
    this.clientId,
    this.clientSecret,
    this.applicationRequestedButMissing = false,
    this.onRetryApplication,
    required this.onDone,
  });

  @override
  State<SetupDonePanel> createState() => _SetupDonePanelState();
}

class _SetupDonePanelState extends State<SetupDonePanel> {
  bool _savedSecret = false;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(Icons.check_circle_outline, size: 72, color: Colors.green),
        const SizedBox(height: 16),
        Text(
          strings.setupComplete,
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 8),
        Text(strings.setupCompleteDescription),
        if (widget.adminUsername != null) ...[
          const SizedBox(height: 8),
          SetupCredentialValue(
            label: strings.administratorUsername,
            value: widget.adminUsername!,
          ),
        ],
        if (widget.applicationRequestedButMissing) ...[
          const SizedBox(height: 12),
          SetupErrorBox(text: strings.setupApplicationMissing),
          if (widget.onRetryApplication != null) ...[
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: widget.onRetryApplication,
              icon: const Icon(Icons.refresh),
              label: Text(strings.retryApplicationCreation),
            ),
          ],
        ],
        if (widget.clientId != null) ...[
          const SizedBox(height: 8),
          SetupCredentialValue(
            label: strings.clientId,
            value: widget.clientId!,
          ),
        ],
        if (widget.clientSecret != null) ...[
          const SizedBox(height: 8),
          SetupCredentialValue(
            label: strings.clientSecret,
            value: widget.clientSecret!,
            shownOnce: true,
          ),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: _savedSecret,
            onChanged: (value) => setState(() => _savedSecret = value ?? false),
            title: Text(strings.secretSavedConfirmation),
            subtitle: Text(strings.secretEraseWarning),
          ),
        ],
        const SizedBox(height: 32),
        FilledButton(
          onPressed: widget.clientSecret == null || _savedSecret
              ? widget.onDone
              : null,
          child: Text(strings.goToAdminConsole),
        ),
      ],
    );
  }
}
