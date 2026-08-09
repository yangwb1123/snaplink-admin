import 'package:flutter/material.dart';
import 'package:sso_admin/i18n/app_strings.dart';

/// Cursor-based pagination controls shared across admin list tabs.
/// Replaces duplicated _PaginationControls, _UserPaginationControls,
/// _TenantPaginationControls in clients_tab, users_tab, tenants_tab.
class PaginationControls extends StatelessWidget {
  /// 当前页号；null = 光标语义（无“Page null”胶囊）。
  final int? page;
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
                context.tr('{total} total', {'total': total}),
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

/// Mixin for cursor-paginated admin list tabs.
/// Provides shared pagination state management for list screens
/// that use SSOAdminClient's cursor-based pagination.
mixin PaginatedListMixin<T extends StatefulWidget> on State<T> {
  final List<String?> _pageTokens = [null];
  int _pageIndex = 0;

  bool get canGoBack => _pageIndex > 0;
  bool? get canGoNext; // null until we know

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

  void goNext(String? nextPageToken) {
    if (nextPageToken == null) return;
    setState(() {
      _pageTokens.removeRange(_pageIndex + 1, _pageTokens.length);
      _pageTokens.add(nextPageToken);
      _pageIndex++;
    });
  }

  String? get currentPageToken => _pageTokens[_pageIndex];
}
