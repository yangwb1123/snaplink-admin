import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sso_admin/widgets/responsive_navigation_scaffold.dart';

const _destinations = [
  NavigationRailDestination(
    icon: Icon(Icons.dashboard_outlined),
    label: Text('Overview'),
  ),
  NavigationRailDestination(
    icon: Icon(Icons.people_outline),
    label: Text('Users'),
  ),
];

Widget _app({required ValueChanged<int> onSelected}) => MaterialApp(
  home: ResponsiveNavigationScaffold(
    appBar: AppBar(title: const Text('Console')),
    selectedIndex: 0,
    onDestinationSelected: onSelected,
    destinations: _destinations,
    drawerHeader: 'Navigation',
    body: const Center(child: Text('Page content')),
  ),
);

void main() {
  testWidgets('uses a drawer and full-width content on narrow screens', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    var selected = -1;
    await tester.pumpWidget(_app(onSelected: (value) => selected = value));

    expect(find.byType(NavigationRail), findsNothing);
    expect(find.text('Page content'), findsOneWidget);

    await tester.tap(find.byTooltip('Open navigation menu'));
    await tester.pumpAndSettle();
    expect(find.text('Navigation'), findsOneWidget);

    await tester.tap(find.text('Users'));
    await tester.pumpAndSettle();
    expect(selected, 1);
  });

  testWidgets('uses a navigation rail on wider screens', (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_app(onSelected: (_) {}));

    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(Drawer), findsNothing);
  });
}
