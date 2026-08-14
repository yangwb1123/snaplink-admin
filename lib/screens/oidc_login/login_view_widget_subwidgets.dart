part of 'login_view_widget.dart';

/// 联合登录（federated provider）按钮：品牌色解析 + 图标/文案渲染。
/// 从 login_view_widget.dart 提取的私有子组件（2026-08 门禁收尾拆分）。
class _FederatedProviderButton extends StatelessWidget {
  final LoginProviderDescriptor provider;
  final bool loading;
  final VoidCallback onPressed;

  const _FederatedProviderButton({required this.provider, required this.loading, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = _parseButtonColor(provider.buttonColor);
    final foreground = color == null
        ? null
        : ThemeData.estimateBrightnessForColor(color) == Brightness.dark ? Colors.white : Colors.black;
    final iconUrl = provider.safeIconUrl(ProductApiOrigin.baseUri);
    final iconColor = color == null ? scheme.primary : foreground;
    final icon = iconUrl == null
        ? Icon(Icons.login, color: iconColor)
        : Image.network(iconUrl, width: 20, height: 20, fit: BoxFit.contain, errorBuilder: (_, _, _) => Icon(Icons.login, color: iconColor));

    return OutlinedButton.icon(
      onPressed: loading ? null : onPressed,
      style: color == null ? null : OutlinedButton.styleFrom(backgroundColor: color, foregroundColor: foreground, side: BorderSide(color: color)),
      icon: icon,
      label: Text(context.tr(provider.effectiveButtonLabel)),
    );
  }

  Color? _parseButtonColor(String raw) {
    final match = RegExp(r'^#([0-9a-fA-F]{6}|[0-9a-fA-F]{8})$').firstMatch(raw.trim());
    if (match == null) return null;
    final hex = match.group(1)!;
    final flutterHex = hex.length == 6 ? 'ff$hex' : '${hex.substring(6)}${hex.substring(0, 6)}';
    return Color(int.parse(flutterHex, radix: 16));
  }
}

/// 内联提示条：图标 + 文案（品牌色/语义色），替代手写 `Text` + `SizedBox`
/// 模板。`contained` 变体用于错误——`errorContainer` 底 + `onErrorContainer`
/// 前景，与 consent 视图的警告容器同风格。
class _InlineNotice extends StatelessWidget {
  final String text;
  final IconData icon;
  final Color color;
  final bool contained;
  final bool liveRegion;

  const _InlineNotice({
    required this.text,
    required this.icon,
    required this.color,
    this.contained = false,
    this.liveRegion = false,
  });

  @override
  Widget build(BuildContext context) {
    final notice = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: TextStyle(color: color))),
      ],
    );
    final wrapped = contained
        ? Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Theme.of(context).colorScheme.errorContainer, borderRadius: BorderRadius.circular(8)),
            child: notice,
          )
        : notice;
    return liveRegion ? Semantics(liveRegion: true, child: wrapped) : wrapped;
  }
}
