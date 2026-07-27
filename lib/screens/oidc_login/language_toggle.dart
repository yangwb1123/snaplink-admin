import 'package:flutter/material.dart';
import 'package:sso_admin/app_settings.dart';

/// Small EN / 中文 toggle shown above every view.
class LanguageToggle extends StatelessWidget {
  const LanguageToggle({super.key});

  @override
  Widget build(BuildContext context) {
    final current = AppSettings.instance.locale.languageCode;
    Widget btn(String code, String label) {
      final sel = current == code;
      return Semantics(
        selected: sel,
        label: code == 'en' ? 'English' : '中文',
        child: TextButton(
          onPressed: () => AppSettings.instance.locale = Locale(code),
          style: TextButton.styleFrom(
            foregroundColor: sel
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          child: Text(
            label,
            style: TextStyle(
              fontWeight: sel ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [btn('en', 'EN'), btn('zh', '中文')],
    );
  }
}
