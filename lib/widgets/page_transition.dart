import 'package:flutter/material.dart';

/// 页面切换过渡：fade + 轻微上滑（Linear/Stripe 风格的内容区切换）。
///
/// 用 [key] 区分页面：切页时旧页淡出、新页淡入并上移 8dp。
/// 有限时长（200ms），不依赖循环动画，测试 settle 安全；减少动态效果时立即切换。
class PageTransition extends StatefulWidget {
  /// 页面标识 key：变化时触发切换动画（新页淡入上移）。
  final Key pageKey;

  /// 被切换的页面内容。
  final Widget child;

  const PageTransition({super.key, required this.pageKey, required this.child});

  @override
  State<PageTransition> createState() => _PageTransitionState();
}

class _PageTransitionState extends State<PageTransition> {
  GlobalKey _contentKey = GlobalKey();

  @override
  void didUpdateWidget(PageTransition oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.pageKey != oldWidget.pageKey) {
      _contentKey = GlobalKey();
    }
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    return AnimatedSwitcher(
      // Existing switcher entries retain their original controller durations.
      // Restart them when motion changes, preserving the current page below.
      key: ValueKey(reduceMotion),
      duration: reduceMotion
          ? Duration.zero
          : const Duration(milliseconds: 200),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      layoutBuilder: (currentChild, previousChildren) => Stack(
        alignment: Alignment.topCenter,
        children: [...previousChildren, ?currentChild],
      ),
      transitionBuilder: (child, animation) {
        final offset =
            Tween<Offset>(
              begin: const Offset(0, 0.015),
              end: Offset.zero,
            ).animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
            );
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(position: offset, child: child),
        );
      },
      child: KeyedSubtree(
        key: widget.pageKey,
        child: KeyedSubtree(key: _contentKey, child: widget.child),
      ),
    );
  }
}
