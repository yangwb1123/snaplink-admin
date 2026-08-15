import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sso_admin/services/shortcut_platform.dart' as shortcut_platform;
import 'package:sso_admin/services/shortcut_service.dart';
import 'package:sso_admin/widgets/search_filter_bar.dart';

/// Scratch verification of the SearchFilterBar focus registry + Ctrl+F
/// wiring through ShortcutService. NOT part of the suite.
void main() {
  setUp(() {
    shortcut_platform.resetForTest();
  });

  testWidgets('SearchFilterBar registers focus and Ctrl+F focuses it', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SearchFilterBar(onSearchChanged: (_) {}),
        ),
      ),
    );

    final field = find.byType(TextField);
    expect(field, findsOneWidget);
    expect(
      tester.widget<TextField>(field).focusNode?.hasFocus,
      isFalse,
      reason: 'no autofocus on SearchFilterBar',
    );

    final service = ShortcutService();
    var searchCalls = 0;
    service.init(onSearch: () {
      searchCalls++;
      SearchFilterBar.focusActiveSearch();
    });
    addTearDown(service.dispose);

    shortcut_platform.testEmitKey('f', true);
    await tester.pump();
    expect(searchCalls, 1);
    expect(
      tester.widget<TextField>(field).focusNode?.hasFocus,
      isTrue,
      reason: 'Ctrl+F focuses the registered search field',
    );
  });

  testWidgets('disposed SearchFilterBar clears the registry', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SearchFilterBar(onSearchChanged: (_) {}),
        ),
      ),
    );
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    // Registry cleared: no stale node to focus → nothing to crash on.
    expect(SearchFilterBar.focusActiveSearch, isNotNull);
    SearchFilterBar.focusActiveSearch();
    expect(tester.takeException(), isNull);
  });
}
