import 'package:flutter/material.dart';

/// 卡片 hover 提升（Linear/Stripe 质感）：悬停时阴影加深、微上浮、边框淡显。
///
/// 包装普通 Card 的交互层——不改变 Card 内部布局，仅叠加状态动画。
/// 有限动画（180ms），测试 settle 安全；非 hover 设备无感知。
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
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        margin: widget.margin,
        transform: Matrix4.translationValues(0, _hovered ? -2 : 0, 0),
        child: Card(
          elevation: _hovered ? widget.hoverElevation : widget.restingElevation,
          child: widget.child,
        ),
      ),
    );
  }
}
