import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:sso_admin/widgets/async_view.dart';

void main() {
  group('AsyncView', () {
    testWidgets('shows loading indicator', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AsyncView<int>(
              loading: true,
              dataBuilder: (data) => Text('Data: $data'),
            ),
          ),
        ),
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('skeleton loading has one live region under reduced motion', (
      tester,
    ) async {
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: MaterialApp(
            home: Scaffold(
              body: AsyncView<int>(
                loading: true,
                useSkeleton: true,
                dataBuilder: (data) => Text('Data: $data'),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.bySemanticsLabel('Loading...'), findsOneWidget);
      expect(tester.binding.hasScheduledFrame, isFalse);
      await tester.pump(const Duration(seconds: 2));
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('keeps dynamic error details verbatim', (tester) async {
      const dynamicError = 'Could not load linked identities.';
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('zh'),
          home: Scaffold(
            body: AsyncView<int>(
              loading: false,
              error: dynamicError,
              dataBuilder: (data) => Text('Data: $data'),
            ),
          ),
        ),
      );
      expect(find.text(dynamicError), findsOneWidget);
    });

    testWidgets('shows error state with retry', (tester) async {
      bool retried = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AsyncView<int>(
              loading: false,
              error: 'Something went wrong',
              onRetry: () => retried = true,
              dataBuilder: (data) => const Text('Data'),
            ),
          ),
        ),
      );
      expect(find.text('Failed to load'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
      await tester.tap(find.text('Retry'));
      expect(retried, true);
    });

    for (final (locale, title, retryLabel) in [
      (const Locale('en'), 'Failed to load', 'Retry'),
      (const Locale('zh'), '加载失败', '重试'),
    ]) {
      testWidgets(
        'full-page error scrolls to manual retry in ${locale.languageCode}',
        (tester) async {
          tester.view.devicePixelRatio = 1;
          tester.view.physicalSize = const Size(320, 240);
          addTearDown(tester.view.reset);
          var retries = 0;
          Widget buildError() => _errorApp(
            locale: locale,
            message: _longErrorDetail,
            textScale: 2,
            onRetry: () => retries++,
          );

          await tester.pumpWidget(buildError());
          expect(tester.takeException(), isNull);
          expect(find.text(title), findsOneWidget);
          expect(find.text(_longErrorDetail), findsOneWidget);
          expect(find.text('Stale data'), findsNothing);
          final paragraph = tester.renderObject<RenderParagraph>(
            find.text(_longErrorDetail),
          );
          expect(paragraph.didExceedMaxLines, isFalse);
          final retry = find.widgetWithText(OutlinedButton, retryLabel);
          expect(retry.hitTestable(), findsNothing);
          expect(retries, 0);

          await tester.pumpWidget(buildError());
          await tester.pump();
          expect(retries, 0, reason: 'Rebuilding must not retry automatically');
          await tester.scrollUntilVisible(
            retry,
            160,
            scrollable: find.byType(Scrollable),
          );
          await tester.pumpAndSettle();
          expect(retry.hitTestable(), findsOneWidget);
          expect(
            tester
                .state<ScrollableState>(find.byType(Scrollable))
                .position
                .pixels,
            greaterThan(0),
          );
          expect(
            tester.getBottomLeft(find.text(_longErrorDetail)).dy,
            inInclusiveRange(0, 240),
          );
          await tester.tap(retry);
          await tester.pump();
          expect(retries, 1);
          await tester.pumpWidget(buildError());
          await tester.pump();
          expect(retries, 1);
          expect(tester.takeException(), isNull);
        },
      );

      testWidgets(
        'full-page error stays centered at an ordinary size in ${locale.languageCode}',
        (tester) async {
          tester.view.devicePixelRatio = 1;
          tester.view.physicalSize = const Size(800, 600);
          addTearDown(tester.view.reset);
          var retries = 0;
          await tester.pumpWidget(
            _errorApp(
              locale: locale,
              message: 'Short synthetic detail.',
              onRetry: () => retries++,
            ),
          );
          expect(tester.takeException(), isNull);
          expect(find.text(title), findsOneWidget);
          expect(find.text('Short synthetic detail.'), findsOneWidget);
          expect(find.text('Stale data'), findsNothing);
          final content = find.descendant(
            of: find.byType(ErrorStateView),
            matching: find.byType(Column),
          );
          expect(tester.getCenter(content), const Offset(400, 300));
          final retry = find.widgetWithText(OutlinedButton, retryLabel);
          expect(retry.hitTestable(), findsOneWidget);
          expect(retries, 0);
          await tester.tap(retry);
          await tester.pump();
          expect(retries, 1);
        },
      );
    }

    testWidgets('full-page error detail scrolls without retry', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 240);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        _errorApp(
          locale: const Locale('en'),
          message: _longErrorDetail,
          textScale: 2,
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.byType(OutlinedButton), findsNothing);
      final detail = find.text(_longErrorDetail);
      expect(detail, findsOneWidget);
      expect(
        tester.renderObject<RenderParagraph>(detail).didExceedMaxLines,
        isFalse,
      );
      final scrollable = tester.state<ScrollableState>(find.byType(Scrollable));
      expect(scrollable.position.maxScrollExtent, greaterThan(0));
      scrollable.position.jumpTo(scrollable.position.maxScrollExtent);
      await tester.pump();
      expect(tester.getBottomLeft(detail).dy, inInclusiveRange(0, 240));
      expect(tester.takeException(), isNull);
    });

    testWidgets('ErrorStateCard stays within narrow viewports', (tester) async {
      const longMessage =
          'This is a long error message with enough words to wrap across '
          'narrow screens safely.';
      addTearDown(tester.view.reset);
      for (final width in [240.0, 320.0, 400.0, 640.0]) {
        for (final message in ['Short error.', longMessage]) {
          for (final title in [null, 'Cannot reach backend']) {
            for (final selectable in [false, true]) {
              for (final retryEnabled in [true, false]) {
                tester.view.devicePixelRatio = 1.0;
                tester.view.physicalSize = Size(width, 600);
                await tester.pumpWidget(
                  MaterialApp(
                    home: Scaffold(
                      body: ErrorStateCard(
                        title: title,
                        message: message,
                        selectable: selectable,
                        onRetry: () {},
                        retryEnabled: retryEnabled,
                      ),
                    ),
                  ),
                );
                expect(find.text(message), findsOneWidget);
                expect(
                  tester.takeException(),
                  isNull,
                  reason:
                      'ErrorStateCard overflowed at $width px, '
                      'title=${title != null}, selectable=$selectable, '
                      'retryEnabled=$retryEnabled',
                );
                final retry = find.widgetWithText(TextButton, 'Retry');
                expect(tester.getSize(retry).width, greaterThanOrEqualTo(48));
                expect(tester.getSize(retry).height, greaterThanOrEqualTo(48));
                final semantics = tester.getSemantics(retry).getSemanticsData();
                expect(semantics.label, 'Retry');
                expect(
                  semantics.flagsCollection.isEnabled == ui.Tristate.isTrue,
                  retryEnabled,
                );
                expect(
                  semantics.hasAction(ui.SemanticsAction.tap),
                  retryEnabled,
                );
              }
            }
          }
        }
      }
    });

    testWidgets(
      'ErrorStateCard retry preserves callback and disabled semantics',
      (tester) async {
        tester.view.devicePixelRatio = 1.0;
        tester.view.physicalSize = const Size(320, 600);
        addTearDown(tester.view.reset);
        var retries = 0;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ErrorStateCard(
                title: 'Cannot reach backend',
                message: 'Short error.',
                onRetry: () => retries++,
                retryEnabled: false,
              ),
            ),
          ),
        );
        final retry = find.widgetWithText(TextButton, 'Retry');
        expect(
          tester.getSemantics(retry),
          matchesSemantics(
            label: 'Retry',
            isButton: true,
            hasEnabledState: true,
            isEnabled: false,
            hasTapAction: false,
          ),
        );
        await tester.tap(retry);
        await tester.pump();
        expect(retries, 0);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ErrorStateCard(
                message: 'Short error.',
                onRetry: () => retries++,
              ),
            ),
          ),
        );
        final enabledRetry = find.widgetWithText(TextButton, 'Retry');
        expect(
          tester.getSemantics(enabledRetry),
          matchesSemantics(
            label: 'Retry',
            isButton: true,
            hasEnabledState: true,
            isEnabled: true,
            hasTapAction: true,
          ),
        );
        expect(
          tester.getSize(enabledRetry).height,
          greaterThanOrEqualTo(kMinInteractiveDimension),
        );
        await tester.tap(enabledRetry);
        await tester.pump();
        expect(retries, 1);
      },
    );

    testWidgets('shows empty state', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AsyncView<List<int>>(
              loading: false,
              data: [],
              emptyTitle: 'No items',
              dataBuilder: (data) => Text('Items: ${data.length}'),
            ),
          ),
        ),
      );
      expect(find.text('No items'), findsOneWidget);
    });

    testWidgets('shows data', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AsyncView<String>(
              loading: false,
              data: 'Hello',
              dataBuilder: (data) => Text(data),
            ),
          ),
        ),
      );
      expect(find.text('Hello'), findsOneWidget);
    });

    testWidgets('null data shows empty state', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AsyncView<String>(
              loading: false,
              data: null,
              dataBuilder: (data) => Text(data),
            ),
          ),
        ),
      );
      expect(find.text('No data'), findsOneWidget);
    });
  });
}

const _longErrorDetail =
    'Synthetic failure detail for fixture-17 reports that the requested view '
    'could not be loaded. This long explanation must remain complete when text '
    'is enlarged and the available viewport is short.\n'
    'Additional synthetic context wraps across multiple lines without changing '
    'the original detail, dropping words, or hiding the manual retry action.\n'
    'Final synthetic detail remains readable.';

Widget _errorApp({
  required Locale locale,
  required String message,
  double textScale = 1,
  VoidCallback? onRetry,
}) => MaterialApp(
  locale: locale,
  supportedLocales: const [Locale('en'), Locale('zh')],
  localizationsDelegates: GlobalMaterialLocalizations.delegates,
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(
      context,
    ).copyWith(textScaler: TextScaler.linear(textScale)),
    child: child!,
  ),
  home: Scaffold(
    body: AsyncView<String>(
      loading: false,
      error: message,
      data: 'Stale data',
      onRetry: onRetry,
      dataBuilder: (data) => Text(data),
    ),
  ),
);
