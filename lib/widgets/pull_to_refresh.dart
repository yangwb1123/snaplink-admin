import 'dart:async';

import 'package:flutter/material.dart';

/// 移动端下拉刷新容器（R56）。
///
/// 在列表页可滚动区外层套 [RefreshIndicator]（下拉刷新），复用页面既有
/// 刷新逻辑，与页头刷新按钮共存不冲突：
/// - `onRefresh` 传既有 `_reload`/`_load`（R5 语义：保留筛选、重置分页、
///   清除选择），两条入口共用同一刷新函数 → 无状态分歧；
/// - 进行中指示与防重入由 [RefreshIndicator] 自带：onRefresh future 未
///   完成前不重复触发，页头刷新按钮也由既有 `_loading`/`_busyId` 禁用；
/// - 内部经 [ScrollConfiguration] 统一注入 `AlwaysScrollableScrollPhysics`：
///   内容不足一屏（短列表/空态）也能下拉触发，无需调用方逐处设置 physics。
///
/// 桌面端（Web/桌面，鼠标键盘）同样可用：拖拽列表顶部即可触发，与刷新
/// 按钮不冲突（同刷新函数 + RefreshIndicator 防重入）。
class PullToRefresh extends StatelessWidget {
  /// 既有刷新逻辑（void 或 Future 均可）。
  final FutureOr<void> Function() onRefresh;

  /// 被包裹的可滚动区（ListView / SingleChildScrollView / 数据表等）。
  final Widget child;

  const PullToRefresh({
    super.key,
    required this.onRefresh,
    required this.child,
  });

  @override
  Widget build(BuildContext context) => RefreshIndicator(
    onRefresh: () async {
      // 错误由页面自身呈现（ErrorStateView/错误卡/错误横幅），下拉刷新
      // 不额外向框架抛未处理异常（页面 Future 仍可被 FutureBuilder 消费）。
      try {
        await onRefresh();
      } catch (_) {
        // Intentionally swallowed: the page's own surface renders the error.
      }
    },
    child: ScrollConfiguration(
      behavior: const _PullToRefreshBehavior(),
      child: child,
    ),
  );
}

/// 包裹区内所有可滚动组件均允许 overscroll（短内容可下拉），其余行为
/// （滚动条、overscroll 指示、平台默认 physics）保持原样。
class _PullToRefreshBehavior extends MaterialScrollBehavior {
  const _PullToRefreshBehavior();

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) =>
      AlwaysScrollableScrollPhysics(parent: super.getScrollPhysics(context));
}
