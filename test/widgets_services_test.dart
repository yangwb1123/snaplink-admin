import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sso_admin/services/browser_download.dart';
import 'package:sso_admin/services/browser_download_stub.dart';
import 'package:sso_admin/services/connectivity_service.dart';
import 'package:sso_admin/services/export_service.dart';
import 'package:sso_admin/services/shortcut_platform.dart' as shortcut_platform;
import 'package:sso_admin/services/shortcut_service.dart';
import 'package:sso_admin/services/connectivity_platform.dart'
    as connectivity_platform;
import 'package:sso_admin/widgets/command_palette.dart';
import 'package:sso_admin/widgets/offline_banner.dart';
import 'package:sso_admin/widgets/paginated_list.dart';
import 'package:sso_admin/widgets/search_filter_bar.dart';
import 'package:sso_admin/services/browser_navigation.dart';

void main() {
  setUp(() {
    shortcut_platform.resetForTest();
    connectivity_platform.resetForTest();
    BrowserDownload.resetForTest();
    BrowserNavigation.resetForTest();
  });

  group('ShortcutService', () {
    test('dispatches Ctrl+N, Ctrl+F, Ctrl+R and Ctrl+K', () {
      final service = ShortcutService();
      var created = 0;
      var searched = 0;
      var refreshed = 0;
      var palette = 0;
      service.init(
        onCreate: () => created++,
        onSearch: () => searched++,
        onRefresh: () => refreshed++,
        onCommandPalette: () => palette++,
      );
      addTearDown(service.dispose);

      shortcut_platform.testEmitKey('n', true);
      shortcut_platform.testEmitKey('f', true);
      shortcut_platform.testEmitKey('r', true);
      shortcut_platform.testEmitKey('k', true);
      expect(created, 1);
      expect(searched, 1);
      expect(refreshed, 1);
      expect(palette, 1);

      // Non-control keys do not trigger actions.
      shortcut_platform.testEmitKey('n', false);
      expect(created, 1);
    });

    test('handles Escape, Ctrl+? and Ctrl+digit navigation', () {
      final service = ShortcutService();
      var escaped = 0;
      var shortcuts = 0;
      var nav = <int>[];
      service.init(
        onEscape: () => escaped++,
        onShowShortcuts: () => shortcuts++,
        onNavigate: (index) => nav.add(index),
      );
      addTearDown(service.dispose);

      shortcut_platform.testEmitKey('Escape', false);
      shortcut_platform.testEmitKey('?', true);
      shortcut_platform.testEmitKey('3', true);
      shortcut_platform.testEmitKey('9', true);
      expect(escaped, 1);
      expect(shortcuts, 1);
      expect(nav, [3, 9]);
    });

    test('does not dispatch after dispose', () {
      final service = ShortcutService();
      var created = 0;
      service.init(onCreate: () => created++);
      service.dispose();

      shortcut_platform.testEmitKey('n', true);
      expect(created, 0);
    });

    test('init is idempotent', () {
      final service = ShortcutService();
      var created = 0;
      service.init(onCreate: () => created++);
      service.init(onCreate: () => created++);
      addTearDown(service.dispose);
      shortcut_platform.testEmitKey('n', true);
      expect(created, 1);
    });
  });

  group('ExportService', () {
    test('exports CSV with proper quoting', () {
      ExportService.exportCsv([
        {'name': 'Ada, Lovelace', 'note': 'said "hello"', 'ok': true},
        {'name': 'Grace\nHopper', 'note': 'plain', 'ok': false},
      ], 'users.csv');
      final captured = capturedDownloads.single;
      expect(captured['filename'], 'users.csv');
      expect(captured['contentType'], 'text/csv;charset=utf-8');
      final csv = utf8.decode(captured['bytes'] as List<int>);
      expect(csv, contains('"Ada, Lovelace"'));
      expect(csv, contains('"said ""hello"""'));
      expect(csv, contains('"Grace\nHopper"'));
      expect(csv, contains('name,note,ok'));
    });

    test('exports indented JSON', () {
      ExportService.exportJson([
        {'id': 1, 'name': 'one'},
      ], 'data.json');
      final captured = capturedDownloads.single;
      expect(captured['filename'], 'data.json');
      expect(captured['contentType'], 'application/json;charset=utf-8');
      final json = utf8.decode(captured['bytes'] as List<int>);
      expect(json, '[\n  {\n    "id": 1,\n    "name": "one"\n  }\n]');
    });

    test('skips empty data without downloading', () {
      ExportService.exportCsv(const [], 'empty.csv');
      expect(capturedDownloads, isEmpty);
    });
  });

  group('ConnectivityService', () {
    testWidgets('reports online by default and streams changes', (
      tester,
    ) async {
      final service = ConnectivityService();
      final events = <bool>[];
      final sub = service.onStatusChanged.listen(events.add);
      // NOTE: the singleton must not be disposed here — later tests (e.g.
      // OfflineBanner) reuse the same instance and its platform listener.
      addTearDown(sub.cancel);

      expect(service.isOnline, isTrue);
      connectivity_platform.testEmitStatus(false);
      // Broadcast stream delivery is asynchronous; idle() flushes microtasks.
      await tester.idle();
      expect(service.isOnline, isFalse);
      connectivity_platform.testEmitStatus(true);
      await tester.idle();
      expect(service.isOnline, isTrue);
      expect(events, [false, true]);
    });
  });

  group('OfflineBanner', () {
    testWidgets('shows a banner when the platform goes offline', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: OfflineBanner(
            child: const Scaffold(body: Center(child: Text('content'))),
          ),
        ),
      );
      expect(
        find.text('You are offline. Some features may be unavailable.'),
        findsNothing,
      );
      expect(find.text('content'), findsOneWidget);

      connectivity_platform.testEmitStatus(false);
      await tester.pump();
      expect(
        find.text('You are offline. Some features may be unavailable.'),
        findsOneWidget,
      );
      expect(find.text('Dismiss'), findsOneWidget);

      connectivity_platform.testEmitStatus(true);
      await tester.pump();
      await tester.pump();
      expect(
        find.text('You are offline. Some features may be unavailable.'),
        findsNothing,
      );
    });
  });

  group('SearchFilterBar', () {
    testWidgets('debounces search input and emits the last value', (
      tester,
    ) async {
      final emitted = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: SearchFilterBar(onSearchChanged: emitted.add)),
        ),
      );

      await tester.enterText(find.byType(TextField), 'a');
      await tester.pump(const Duration(milliseconds: 100));
      expect(emitted, isEmpty); // debounce window still open
      await tester.enterText(find.byType(TextField), 'ab');
      await tester.pump(const Duration(milliseconds: 350));
      expect(emitted, ['ab']);
    });

    testWidgets('toggles filter chips and refreshes', (tester) async {
      String? selected;
      final changed = <String?>[];
      var refreshed = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SearchFilterBar(
              filterOptions: const ['active', 'suspended'],
              selectedFilter: selected,
              onSearchChanged: (_) {},
              onFilterChanged: (value) {
                selected = value;
                changed.add(value);
              },
              onRefresh: () => refreshed++,
            ),
          ),
        ),
      );

      // Filters hidden until toggled.
      expect(find.text('active'), findsNothing);
      await tester.tap(find.byTooltip('Toggle filters'));
      await tester.pumpAndSettle();
      expect(find.text('active'), findsOneWidget);

      await tester.tap(find.text('active'));
      expect(changed, ['active']);

      // Rebuild with the chip selected; tapping it again clears the filter.
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SearchFilterBar(
              filterOptions: const ['active', 'suspended'],
              selectedFilter: selected,
              onSearchChanged: (_) {},
              onFilterChanged: (value) {
                selected = value;
                changed.add(value);
              },
              onRefresh: () => refreshed++,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('active'));
      expect(changed, ['active', null]);

      await tester.tap(find.byIcon(Icons.refresh));
      expect(refreshed, 1);
    });
  });

  group('PaginationControls', () {
    testWidgets('shows page info and forwards navigation callbacks', (
      tester,
    ) async {
      var previous = 0;
      var next = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PaginationControls(
              page: 2,
              total: 57,
              canGoBack: true,
              canGoNext: true,
              onPrevious: () => previous++,
              onNext: () => next++,
            ),
          ),
        ),
      );

      expect(find.text('Page 2 · 57 total'), findsOneWidget);
      await tester.tap(find.text('Previous'));
      await tester.tap(find.text('Next'));
      expect(previous, 1);
      expect(next, 1);
    });

    testWidgets('disables buttons when edges are reached', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PaginationControls(
              page: 1,
              total: 1,
              canGoBack: false,
              canGoNext: false,
              onPrevious: () {},
              onNext: () {},
            ),
          ),
        ),
      );
      final previous = tester.widget<OutlinedButton>(
        find.ancestor(
          of: find.text('Previous'),
          matching: find.byType(OutlinedButton),
        ),
      );
      final next = tester.widget<OutlinedButton>(
        find.ancestor(
          of: find.text('Next'),
          matching: find.byType(OutlinedButton),
        ),
      );
      expect(previous.onPressed, isNull);
      expect(next.onPressed, isNull);
    });
  });

  group('CommandPalette', () {
    testWidgets('lists module commands and filters by query', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: TextButton(
                  onPressed: () => CommandPalette.show(
                    context,
                    currentModule: 'clients',
                    allModules: const ['clients', 'users'],
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.byType(CommandPalette), findsOneWidget);
      // The footer shows the command count (the hint also contains
      // "commands", so scope to the footer text).
      expect(find.textContaining('commands'), findsWidgets);

      await tester.enterText(find.byType(TextField), 'client');
      await tester.pumpAndSettle();
      // At least the clients command remains visible.
      expect(find.textContaining('clients'), findsWidgets);

      await tester.enterText(find.byType(TextField), 'zzz-no-match');
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Type to search · 0 commands'),
        findsOneWidget,
      );
    });
  });
}
