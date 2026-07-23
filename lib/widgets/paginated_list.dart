import 'package:flutter/material.dart';

/// Cursor-based pagination controls shared across admin list tabs.
/// Replaces duplicated _PaginationControls, _UserPaginationControls,
/// _TenantPaginationControls in clients_tab, users_tab, tenants_tab.
class PaginationControls extends StatelessWidget {
  final int page;
  final int? total;
  final bool canGoBack;
  final bool canGoNext;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  const PaginationControls({
    super.key,
    required this.page,
    required this.total,
    required this.canGoBack,
    required this.canGoNext,
    required this.onPrevious,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(12),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        OutlinedButton.icon(
          onPressed: canGoBack ? onPrevious : null,
          icon: const Icon(Icons.chevron_left),
          label: const Text('Previous'),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            total == null ? 'Page $page' : 'Page $page · $total total',
          ),
        ),
        OutlinedButton.icon(
          onPressed: canGoNext ? onNext : null,
          icon: const Icon(Icons.chevron_right),
          label: const Text('Next'),
        ),
      ],
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
