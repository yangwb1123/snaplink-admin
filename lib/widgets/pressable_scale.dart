import 'package:flutter/material.dart';

/// 按钮按压反馈：按下时轻微缩小（0.98），松手回弹（Stripe/Linear 触感）。
///
/// 包在按钮外，不改变按钮本身样式。有限动画（90ms），测试 settle 安全。
/// 禁用按钮（onPressed == null）不产生按压缩放：loading/busy 中按钮已
/// 禁用，按下不应再有反馈动画（R35 反馈一致性）。
class PressableScale extends StatefulWidget {
  /// 被包装的按钮/可点击控件（不改变其样式）。
  final Widget child;

  const PressableScale({super.key, required this.child});

  @override
  State<PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<PressableScale> {
  bool _pressed = false;

  /// 被包装按钮为禁用态（onPressed == null）时不缩放：禁用控件无按压反馈。
  bool get _childDisabled =>
      widget.child is ButtonStyleButton &&
      (widget.child as ButtonStyleButton).onPressed == null;

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) {
        if (_childDisabled) return;
        setState(() => _pressed = true);
      },
      onPointerUp: (_) => setState(() => _pressed = false),
      onPointerCancel: (_) => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.98 : 1,
        duration: const Duration(milliseconds: 90),
        curve: Curves.easeOutCubic,
        child: widget.child,
      ),
    );
  }
}
