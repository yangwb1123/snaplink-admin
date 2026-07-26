import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:sso_admin/widgets/async_view.dart';

void main() {
  group('AsyncView', () {
    testWidgets('shows loading indicator', (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: Scaffold(
          body: AsyncView<int>(
            loading: true,
            dataBuilder: (data) => Text('Data: $data'),
          ),
        )),
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('shows error state with retry', (tester) async {
      bool retried = false;
      await tester.pumpWidget(
        MaterialApp(home: Scaffold(
          body: AsyncView<int>(
            loading: false,
            error: 'Something went wrong',
            onRetry: () => retried = true,
            dataBuilder: (data) => const Text('Data'),
          ),
        )),
      );
      expect(find.text('Failed to load'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
      await tester.tap(find.text('Retry'));
      expect(retried, true);
    });

    testWidgets('shows empty state', (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: Scaffold(
          body: AsyncView<List<int>>(
            loading: false,
            data: [],
            emptyTitle: 'No items',
            dataBuilder: (data) => Text('Items: ${data.length}'),
          ),
        )),
      );
      expect(find.text('No items'), findsOneWidget);
    });

    testWidgets('shows data', (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: Scaffold(
          body: AsyncView<String>(
            loading: false,
            data: 'Hello',
            dataBuilder: (data) => Text(data),
          ),
        )),
      );
      expect(find.text('Hello'), findsOneWidget);
    });

    testWidgets('null data shows empty state', (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: Scaffold(
          body: AsyncView<String>(
            loading: false,
            data: null,
            dataBuilder: (data) => Text(data),
          ),
        )),
      );
      expect(find.text('No data'), findsOneWidget);
    });
  });
}
