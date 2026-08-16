import 'package:flutter/material.dart';

/// Responsive, keyboard-safe shell shared by the public entry surfaces.
///
/// The compact padding keeps form controls usable on narrow phones while the
/// scroll view prevents the software keyboard or large text from clipping the
/// final action. Visual style is injectable through optional parameters (the
/// login shell passes its Sentry-style card, login-redesign §2); the defaults
/// preserve the app theme for setup/device consumers.
class ResponsiveEntryCard extends StatelessWidget {
  final Widget child;
  final double maxWidth;

  /// 卡片圆角（覆盖主题值；null = 主题 cardTheme 圆角）。
  final BorderRadius? borderRadius;

  /// 卡片 1px 边框（null = 无边框，保持主题默认）。
  final BorderSide? borderSide;

  /// 卡片表面色（null = 主题 cardTheme 表面色）。
  final Color? surfaceColor;

  /// 卡片抬升（null = 主题 cardTheme 抬升）。
  final double? elevation;

  const ResponsiveEntryCard({
    super.key,
    required this.child,
    this.maxWidth = 440,
    this.borderRadius,
    this.borderSide,
    this.surfaceColor,
    this.elevation,
  });

  @override
  Widget build(BuildContext context) {
    final cardTheme = Theme.of(context).cardTheme;
    final radius =
        borderRadius ??
        ((cardTheme.shape is RoundedRectangleBorder)
            ? (cardTheme.shape! as RoundedRectangleBorder).borderRadius
            : BorderRadius.circular(12));
    return SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 400;
          final outer = compact ? 12.0 : 24.0;
          final inner = compact ? 20.0 : 24.0;
          final minHeight = constraints.hasBoundedHeight
              ? (constraints.maxHeight - outer * 2).clamp(0.0, double.infinity)
              : 0.0;
          return SingleChildScrollView(
            padding: EdgeInsets.all(outer),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: minHeight),
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxWidth),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: 1),
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOutCubic,
                    builder: (context, value, child) => Opacity(
                      opacity: value.clamp(0.0, 1.0),
                      child: Transform.translate(
                        offset: Offset(0, 12 * (1 - value)),
                        child: child,
                      ),
                    ),
                    child: Card(
                      elevation: elevation ?? cardTheme.elevation ?? 1,
                      color: surfaceColor ?? cardTheme.color,
                      shape: RoundedRectangleBorder(
                        borderRadius: radius,
                        side: borderSide ?? BorderSide.none,
                      ),
                      child: Padding(
                        padding: EdgeInsets.all(inner),
                        child: child,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
