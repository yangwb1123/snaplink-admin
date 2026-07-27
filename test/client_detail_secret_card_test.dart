import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sso_admin/screens/admin/client_detail_secret_card.dart';

void main() {
  testWidgets('rotated client secret requires explicit save acknowledgement', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => FilledButton(
              onPressed: () =>
                  showClientDetailSecret(context, 'one-time-client-secret'),
              child: const Text('Rotate'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Rotate'));
    await tester.pumpAndSettle();
    expect(find.text('one-time-client-secret'), findsOneWidget);

    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();
    expect(find.text('one-time-client-secret'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('one-time-client-secret'), findsOneWidget);

    await tester.tap(find.text('I have saved it — clear secret'));
    await tester.pumpAndSettle();
    expect(find.text('one-time-client-secret'), findsNothing);
  });
}
