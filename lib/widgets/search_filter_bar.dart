import 'dart:async';
import 'package:flutter/material.dart';

/// Reusable search and filter bar for list pages.
/// Supports text search, filter chips, and sort selection.
class SearchFilterBar extends StatefulWidget {
  final String hintText;
  final List<String> filterOptions;
  final String? selectedFilter;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String?>? onFilterChanged;
  final VoidCallback? onRefresh;

  const SearchFilterBar({
    super.key,
    this.hintText = 'Search...',
    this.filterOptions = const [],
    this.selectedFilter,
    required this.onSearchChanged,
    this.onFilterChanged,
    this.onRefresh,
  });

  @override
  State<SearchFilterBar> createState() => _SearchFilterBarState();
}

class _SearchFilterBarState extends State<SearchFilterBar> {
  final _searchCtrl = TextEditingController();
  bool _showFilters = false;
  Timer? _debounceTimer;

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      widget.onSearchChanged(value);
    });
  }

  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
              child: TextField(
                controller: _searchCtrl,
                decoration: InputDecoration(
                  hintText: widget.hintText,
                  prefixIcon: const Icon(Icons.search, size: 20),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  isDense: true,
                ),
                onChanged: _onSearchChanged,
              ),
            ),
            if (widget.filterOptions.isNotEmpty) ...[
              const SizedBox(width: 8),
              IconButton(
                icon: Icon(
                  _showFilters ? Icons.filter_list_off : Icons.filter_list,
                  size: 20,
                ),
                tooltip: 'Toggle filters',
                onPressed: () => setState(() => _showFilters = !_showFilters),
              ),
            ],
            if (widget.onRefresh != null) ...[
              const SizedBox(width: 4),
              IconButton(
                icon: const Icon(Icons.refresh, size: 20),
                tooltip: 'Refresh',
                onPressed: widget.onRefresh,
              ),
            ],
          ]),
          if (_showFilters && widget.filterOptions.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                for (final option in widget.filterOptions)
                  FilterChip(
                    label: Text(option, style: const TextStyle(fontSize: 12)),
                    selected: widget.selectedFilter == option,
                    onSelected: (_) => widget.onFilterChanged?.call(
                      widget.selectedFilter == option ? null : option,
                    ),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
              ],
            ),
          ],
        ],
      ),
    ),
  );
}
