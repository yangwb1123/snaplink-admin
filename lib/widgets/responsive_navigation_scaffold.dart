import 'package:flutter/material.dart';

/// An application shell that keeps the content area usable on narrow screens.
///
/// Phones receive a scrollable drawer, medium layouts use a compact rail, and
/// wide layouts reveal every rail label. The selected destination callback is
/// intentionally invoked even when the selected drawer item is tapped so a
/// detail route can return to its module's list route.
class ResponsiveNavigationScaffold extends StatelessWidget {
  static const double drawerBreakpoint = 720;
  static const double labeledRailBreakpoint = 1180;

  final PreferredSizeWidget appBar;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final List<NavigationRailDestination> destinations;
  final Widget body;
  final String drawerHeader;

  const ResponsiveNavigationScaffold({
    super.key,
    required this.appBar,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.destinations,
    required this.body,
    required this.drawerHeader,
  });

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final useDrawer = constraints.maxWidth < drawerBreakpoint;
      return Scaffold(
        appBar: appBar,
        drawer: useDrawer
            ? Drawer(
                child: SafeArea(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                        child: Text(
                          drawerHeader,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                      const Divider(height: 1),
                      Expanded(
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          itemCount: destinations.length,
                          itemBuilder: (context, index) {
                            final destination = destinations[index];
                            final selected = index == selectedIndex;
                            return ListTile(
                              selected: selected,
                              leading: selected
                                  ? destination.selectedIcon
                                  : destination.icon,
                              title: destination.label,
                              onTap: () {
                                Navigator.of(context).pop();
                                onDestinationSelected(index);
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              )
            : null,
        body: useDrawer
            ? body
            : Row(
                children: [
                  NavigationRail(
                    selectedIndex: selectedIndex,
                    onDestinationSelected: onDestinationSelected,
                    labelType: constraints.maxWidth >= labeledRailBreakpoint
                        ? NavigationRailLabelType.all
                        : NavigationRailLabelType.selected,
                    scrollable: true,
                    // 品牌化：窄轨道 + 选中态圆角块（Linear/Vercel 风格）。
                    groupAlignment: -0.9,
                    selectedIconTheme: IconThemeData(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    unselectedIconTheme: IconThemeData(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    indicatorColor: Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.12),
                    destinations: destinations,
                  ),
                  const VerticalDivider(width: 1),
                  Expanded(child: body),
                ],
              ),
      );
    },
  );
}
