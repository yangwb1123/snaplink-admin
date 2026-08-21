import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

/// 登录卡玻璃拟态总开关（login-redesign-2 §2）：false = 回退纯半透明卡片
/// （无 BackdropFilter），供 HTML renderer / 特殊无 GPU 环境降级。
const bool kLoginCardBlur = true;

/// Responsive, keyboard-safe shell shared by the public entry surfaces.
///
/// The compact padding keeps form controls usable on narrow phones while the
/// scroll view prevents the software keyboard or large text from clipping the
/// final action. Visual style is injectable through optional parameters (the
/// login shell passes its glass card, redesign-2 §2); the defaults preserve
/// the app theme for setup/device consumers.
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

  /// 卡片背板模糊半径（px；null = 无 BackdropFilter，保持主题现状）。
  /// 非 null 时按 `ClipRRect > BackdropFilter > Card` 配方包裹——blur 采样
  /// 被圆角裁剪，有界于卡片区域（不用于全屏）。
  final double? backdropBlur;

  const ResponsiveEntryCard({
    super.key,
    required this.child,
    this.maxWidth = 440,
    this.borderRadius,
    this.borderSide,
    this.surfaceColor,
    this.elevation,
    this.backdropBlur,
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
          final card = Card(
            elevation: elevation ?? cardTheme.elevation ?? 1,
            color: surfaceColor ?? cardTheme.color,
            shape: RoundedRectangleBorder(
              borderRadius: radius,
              side: borderSide ?? BorderSide.none,
            ),
            child: Padding(padding: EdgeInsets.all(inner), child: child),
          );
          final blur = backdropBlur;
          // 入场动画（fade + 轻上滑）保持既有结构；blur 时 `ClipRRect >
          // BackdropFilter > 动画子树`——滤镜必须位于 Opacity saveLayer
          // 之外才能采样页面背景（极光），ClipRRect 使采样有界于卡片区域。
          final animatedCard = TweenAnimationBuilder<double>(
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
            child: card,
          );
          return SingleChildScrollView(
            padding: EdgeInsets.all(outer),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: minHeight),
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxWidth),
                  child: blur == null
                      ? animatedCard
                      : ClipRRect(
                          borderRadius: radius,
                          child: BackdropFilter(
                            filter: ImageFilter.blur(
                              sigmaX: blur,
                              sigmaY: blur,
                            ),
                            child: animatedCard,
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
