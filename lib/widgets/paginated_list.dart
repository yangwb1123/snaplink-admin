import 'package:flutter/material.dart';
import 'package:sso_admin/i18n/app_strings.dart';
import 'package:sso_admin/widgets/empty_state.dart';
import 'package:sso_admin/widgets/format_helpers.dart';

/// Cursor-based pagination controls shared across admin list tabs.
/// Replaces duplicated _PaginationControls, _UserPaginationControls,
/// _TenantPaginationControls in clients_tab, users_tab, tenants_tab.
class PaginationControls extends StatelessWidget {
  /// 当前页号；null = 光标语义（无“Page null”胶囊）。
  final int? page;

  /// 总数（渲染 `{total} total` 徽章）；null = 不渲染。
  final int? total;

  /// 非空时替代 `{total} total` 徽章渲染汇总文案（SCIM 语义）。
  final String? summaryLabel;
  final Map<String, String>? summaryArgs;

  final bool canGoBack;
  final bool canGoNext;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  const PaginationControls({
    super.key,
    required this.page,
    required this.total,
    this.summaryLabel,
    this.summaryArgs,
    required this.canGoBack,
    required this.canGoNext,
    required this.onPrevious,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(12),
    child: LayoutBuilder(
      builder: (context, constraints) {
        final previous = OutlinedButton.icon(
          onPressed: canGoBack ? onPrevious : null,
          icon: const Icon(Icons.chevron_left),
          label: Text(context.tr('Previous')),
        );
        final next = OutlinedButton.icon(
          onPressed: canGoNext ? onNext : null,
          icon: const Icon(Icons.chevron_right),
          label: Text(context.tr('Next')),
        );
        // 当前页胶囊（品牌色高亮）+ 总数/汇总徽章。
        final pill = page == null
            ? null
            : Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  context.tr('Page {page}', {'page': page}),
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              );
        final summary = summaryLabel != null
            ? Text(
                context.tr(
                  summaryLabel!,
                  summaryArgs == null
                      ? const <String, Object?>{}
                      : <String, Object?>{...summaryArgs!},
                ),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              )
            : total == null
            ? null
            : Text(
                context.tr('{total} total', {'total': formatCount(total)}),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              );
        final children = <Widget>[previous, ?pill, ?summary, next];
        // 窄视口换行：<560 走 Wrap，否则保持原 Row 节奏。
        if (constraints.maxWidth < 560) {
          return Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: children,
          );
        }
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0) const SizedBox(width: 8),
              children[i],
            ],
          ],
        );
      },
    ),
  );
}

/// 非首页空页：游标/页码已越过数据尾（数据在浏览期间收缩/变更）。
/// 提示回到第一页，避免把“此页无数据”误读为“列表为空”（R46）。
class EmptyPageState extends StatelessWidget {
  final VoidCallback onBackToFirst;

  const EmptyPageState({super.key, required this.onBackToFirst});

  @override
  Widget build(BuildContext context) => EmptyState(
    variant: EmptyStateVariant.noMatch,
    icon: Icons.first_page,
    title: 'No data on this page',
    subtitle: 'The data may have changed since you last loaded this page.',
    actionLabel: 'Back to first page',
    actionIcon: Icons.first_page,
    onAction: onBackToFirst,
  );
}

/// Mixin for cursor-paginated admin list tabs.
/// Provides shared pagination state management for list screens
/// that use SSOAdminClient's cursor-based pagination.
mixin PaginatedListMixin<T extends StatefulWidget> on State<T> {
  final List<String?> _pageTokens = [null];
  int _pageIndex = 0;

  bool get canGoBack => _pageIndex > 0;
  bool? get canGoNext; // null until we know

  /// 是否停留在第一页：空态据此区分“列表为空”与“非首页无数据”。
  bool get onFirstPage => _pageIndex == 0;

  int get currentPage => _pageIndex + 1;

  void resetPagination() {
    _pageTokens
      ..clear()
      ..add(null);
    _pageIndex = 0;
  }

  void goPrevious() {
    if (_pageIndex == 0) return;
    setState(() {
      _pageIndex--;
    });
  }

  /// 记录上一帧已推进的页对象：同帧双触发（连点 Next）只推进一次，
  /// 页面重新加载后对象变化即自然失效（防重入，R46）。
  Object? _lastAdvancedPage;

  void goNext(String? nextPageToken, {Object? page}) {
    if (nextPageToken == null) return;
    if (identical(_lastAdvancedPage, page)) return; // 防重入
    _lastAdvancedPage = page;
    setState(() {
      _pageTokens.removeRange(_pageIndex + 1, _pageTokens.length);
      _pageTokens.add(nextPageToken);
      _pageIndex++;
    });
  }

  String? get currentPageToken => _pageTokens[_pageIndex];
}
