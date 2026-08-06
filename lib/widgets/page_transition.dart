import 'package:flutter/material.dart';

/// 页面切换过渡：fade + 轻微上滑（Linear/Stripe 风格的内容区切换）。
///
/// 用 [key] 区分页面：切页时旧页淡出、新页淡入并上移 8dp。
/// 有限时长（200ms），不依赖循环动画，测试 settle 安全。
class PageTransition extends StatelessWidget {
  final Key pageKey;
  final Widget child;

  const PageTransition({super.key, required this.pageKey, required this.child});

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      layoutBuilder: (currentChild, previousChildren) => Stack(
        alignment: Alignment.topCenter,
        children: [...previousChildren, ?currentChild],
      ),
      transitionBuilder: (child, animation) {
        final offset = Tween<Offset>(
          begin: const Offset(0, 0.015),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic));
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(position: offset, child: child),
        );
      },
      child: KeyedSubtree(key: pageKey, child: child),
    );
  }
}
