import 'package:flutter/material.dart';

/// 卡片 hover 提升（Linear/Stripe 质感）：悬停时阴影加深、微上浮、边框淡显。
///
/// 包装普通 Card 的交互层——不改变 Card 内部布局，仅叠加状态动画。
/// 一次性 150ms 过渡（R7 约定，与行/卡 hover 底色、登录 _HoverTint 一致），
/// 测试 settle 安全；非 hover 设备无感知。
class HoverCard extends StatefulWidget {
  /// 被包装的卡片内容（保持内部布局不变）。
  final Widget child;

  /// 外边距；null = 主题默认。
  final EdgeInsetsGeometry? margin;

  /// 悬停时阴影高度（默认 6）。
  final double hoverElevation;

  /// 静止阴影高度（默认 1）。
  final double restingElevation;

  const HoverCard({
    super.key,
    required this.child,
    this.margin,
    this.hoverElevation = 6,
    this.restingElevation = 1,
  });

  @override
  State<HoverCard> createState() => _HoverCardState();
}

class _HoverCardState extends State<HoverCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOutCubic,
        margin: widget.margin,
        transform: Matrix4.translationValues(0, _hovered ? -2 : 0, 0),
        child: Card(
          // R18：dark 下阴影不可感知（elevation 0 已禁用），hover 提升
          // 改用 surface 层级——surfaceContainerHigh 对脚手架背景
          // ≈1.66:1（静止 surface ≈1.22:1），无阴影同样可感知抬升；
          // 浅色保持阴影方案不变。
          elevation: isDark
              ? 0
              : (_hovered ? widget.hoverElevation : widget.restingElevation),
          color: isDark && _hovered
              ? theme.colorScheme.surfaceContainerHigh
              : null,
          child: widget.child,
        ),
      ),
    );
  }
}
