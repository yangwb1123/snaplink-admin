import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sso_admin/widgets/error_boundary.dart';

void main() {
  group('ErrorBoundary', () {
    testWidgets('shows child when no error', (tester) async {
      await _withErrorHooks(tester, (hooks) async {
        await tester.pumpWidget(_boundaries(second: false));
        expect(find.text('First child'), findsOneWidget);
        expect(hooks.errors, isEmpty);
      });
    });

    for (final removeFirst in [true, false]) {
      for (final originallyNull in [false, true]) {
        testWidgets(
          'restores ${originallyNull ? 'null' : 'app handler'} when disposing '
          '${removeFirst ? 'oldest' : 'newest'} first',
          (tester) async {
            await _withErrorHooks(tester, (hooks) async {
              final original = originallyNull ? null : hooks.appHandler;
              FlutterError.onError = original;
              await tester.pumpWidget(_boundaries());
              await tester.pumpWidget(
                _boundaries(first: !removeFirst, second: removeFirst),
              );

              final details = _error();
              FlutterError.reportError(details);
              await _flushError(tester);
              expect(
                find.text(removeFirst ? 'Second failure' : 'First failure'),
                findsOneWidget,
              );
              expect(hooks.errors, originallyNull ? isEmpty : [same(details)]);
              expect(
                hooks.presentations,
                originallyNull ? isEmpty : [same(details)],
              );

              await tester.pumpWidget(_boundaries(first: false, second: false));
              expect(FlutterError.onError, same(original));
              expect(tester.takeException(), isNull);
            });
          },
        );
      }
    }

    testWidgets('forwards each report once and only newest boundary reacts', (
      tester,
    ) async {
      await _withErrorHooks(tester, (hooks) async {
        await tester.pumpWidget(_boundaries());
        final details = _error();
        FlutterError.reportError(details);
        FlutterError.reportError(details);
        await _flushError(tester);

        expect(hooks.errors, [same(details), same(details)]);
        expect(hooks.presentations, [same(details), same(details)]);
        expect(find.text('Second failure'), findsOneWidget);
        expect(find.text('First child'), findsOneWidget);
        expect(find.text('First failure'), findsNothing);
      });
    });

    for (final removeFirst in [true, false]) {
      testWidgets('preserves external replacement when disposing '
          '${removeFirst ? 'oldest' : 'newest'} first', (tester) async {
        await _withErrorHooks(tester, (hooks) async {
          await tester.pumpWidget(_boundaries());
          final capturedHandler = FlutterError.onError!;
          final externalErrors = <FlutterErrorDetails>[];
          void replacement(FlutterErrorDetails details) {
            externalErrors.add(details);
            capturedHandler(details);
          }

          FlutterError.onError = replacement;
          await tester.pumpWidget(
            _boundaries(first: !removeFirst, second: removeFirst),
          );
          expect(FlutterError.onError, same(replacement));
          final remainingError = _error();
          FlutterError.reportError(remainingError);
          await _flushError(tester);
          expect(
            find.text(removeFirst ? 'Second failure' : 'First failure'),
            findsOneWidget,
          );

          await tester.pumpWidget(_boundaries(first: false, second: false));
          expect(FlutterError.onError, same(replacement));
          final afterDisposal = _error();
          FlutterError.reportError(afterDisposal);
          await _flushError(tester);
          expect(externalErrors, [same(remainingError), same(afterDisposal)]);
          expect(hooks.errors, [same(remainingError), same(afterDisposal)]);
          expect(hooks.presentations, hooks.errors);
          expect(find.byType(ErrorBoundary), findsNothing);
          expect(tester.takeException(), isNull);
        });
      });
    }

    testWidgets('breaks forwarding cycles without swallowing distinct errors', (
      tester,
    ) async {
      await _withErrorHooks(tester, (hooks) async {
        final first = _error();
        final unrelated = _error();
        FlutterError.onError = (details) {
          hooks.appHandler(details);
          // Simulate an app handler forwarding back through the global hook.
          FlutterError.reportError(details);
          if (identical(details, first)) {
            FlutterError.reportError(unrelated);
          }
        };
        await tester.pumpWidget(_boundaries());
        FlutterError.reportError(first);
        await _flushError(tester);

        expect(hooks.errors, [same(first), same(unrelated)]);
        expect(hooks.presentations, hooks.errors);
        expect(find.text('Second failure'), findsOneWidget);
        expect(find.text('First child'), findsOneWidget);
      });
    });

    testWidgets('restores forwarding after an app handler throws', (
      tester,
    ) async {
      await _withErrorHooks(tester, (hooks) async {
        final appFailure = StateError('Synthetic app handler failure');
        var shouldThrow = true;
        FlutterError.onError = (details) {
          hooks.appHandler(details);
          if (shouldThrow) throw appFailure;
        };
        await tester.pumpWidget(_boundaries());
        final details = _error();
        expect(
          () => FlutterError.reportError(details),
          throwsA(same(appFailure)),
        );
        shouldThrow = false;
        FlutterError.reportError(details);
        await _flushError(tester);
        expect(hooks.errors, [same(details), same(details)]);
        expect(hooks.presentations, hooks.errors);
      });
    });

    testWidgets('defers descendant build failure safely and Retry rebuilds', (
      tester,
    ) async {
      await _withErrorHooks(tester, (hooks) async {
        var fail = true;
        await tester.pumpWidget(
          _app(
            ErrorBoundary(
              child: Builder(
                builder: (_) {
                  if (fail) throw StateError(_sensitiveMarker);
                  return const Text('Recovered child');
                },
              ),
            ),
          ),
        );
        await _flushError(tester);

        // Only the original failure reaches the app, not a build-phase
        // setState error caused by the boundary's own error handling.
        expect(hooks.errors, hasLength(1));
        expect(hooks.errors.single.exception, isA<StateError>());
        expect(find.text('Something went wrong'), findsOneWidget);
        expect(find.textContaining(_sensitiveMarker), findsNothing);
        expect(find.byType(ErrorWidget), findsNothing);
        expect(tester.takeException(), isNull);

        fail = false;
        await tester.tap(find.text('Retry'));
        await tester.pump();
        expect(find.text('Recovered child'), findsOneWidget);
        expect(find.text('Something went wrong'), findsNothing);
        expect(hooks.errors, hasLength(1));
      });
    });

    testWidgets('nested build failure leaves the outer boundary intact', (
      tester,
    ) async {
      await _withErrorHooks(tester, (hooks) async {
        await tester.pumpWidget(
          _app(
            ErrorBoundary(
              label: 'Outer failure',
              child: ErrorBoundary(
                label: 'Inner failure',
                child: Builder(
                  builder: (_) => throw StateError(_sensitiveMarker),
                ),
              ),
            ),
          ),
        );
        await _flushError(tester);
        expect(find.text('Inner failure'), findsOneWidget);
        expect(find.text('Outer failure'), findsNothing);
        expect(hooks.errors, hasLength(1));
        expect(hooks.presentations, hooks.errors);
      });
    });

    testWidgets('disposal before deferred build-error handling is safe', (
      tester,
    ) async {
      await _withErrorHooks(tester, (hooks) async {
        await tester.pumpWidget(const SizedBox.shrink());
        final binding = tester.binding;
        // Build synchronously so we can unmount before post-frame callbacks,
        // rather than letting pumpWidget complete the whole frame first.
        binding.attachRootWidget(
          binding.wrapWithDefaultView(
            _app(
              ErrorBoundary(
                child: Builder(
                  builder: (_) => throw StateError(_sensitiveMarker),
                ),
              ),
            ),
          ),
        );
        binding.buildOwner!.buildScope(binding.rootElement!);
        expect(hooks.errors, hasLength(1));
        final details = hooks.errors.single;
        expect(details.exception, isA<StateError>());
        binding.attachRootWidget(
          binding.wrapWithDefaultView(const SizedBox.shrink()),
        );
        binding.buildOwner!.buildScope(binding.rootElement!);
        binding.buildOwner!.finalizeTree();
        expect(FlutterError.onError, same(hooks.appHandler));

        await _flushError(tester);
        expect(hooks.errors, [same(details)]);
        expect(hooks.presentations, hooks.errors);
        expect(find.byType(ErrorBoundary), findsNothing);
        expect(tester.takeException(), isNull);
      });
    });

    for (final chinese in [false, true]) {
      for (final customLabel in [false, true]) {
        testWidgets(
          'localizes ${customLabel ? 'custom' : 'default'} fallback and Retry '
          'in ${chinese ? 'ZH' : 'EN'} without exception details',
          (tester) async {
            await _withErrorHooks(tester, (hooks) async {
              await tester.pumpWidget(
                _app(
                  ErrorBoundary(
                    label: customLabel ? 'Retry discovery' : null,
                    child: const Text('Protected child'),
                  ),
                  locale: Locale(chinese ? 'zh' : 'en'),
                ),
              );
              FlutterError.reportError(_error());
              await _flushError(tester);
              final expected = customLabel
                  ? (chinese ? '重试发现' : 'Retry discovery')
                  : (chinese ? '发生了错误' : 'Something went wrong');
              expect(find.text(expected), findsOneWidget);
              expect(find.textContaining(_sensitiveMarker), findsNothing);
              expect(
                find.widgetWithText(OutlinedButton, chinese ? '重试' : 'Retry'),
                findsOneWidget,
              );

              await tester.tap(
                find.widgetWithIcon(OutlinedButton, Icons.refresh),
              );
              await tester.pump();
              expect(find.text('Protected child'), findsOneWidget);
              expect(hooks.errors, hasLength(1));
            });
          },
        );
      }
    }
  });
}

const _sensitiveMarker = 'SYNTHETIC-SENSITIVE-ERROR-DETAIL';

FlutterErrorDetails _error() => FlutterErrorDetails(
  exception: StateError(_sensitiveMarker),
  library: 'synthetic unrelated error',
);

Widget _app(Widget child, {Locale locale = const Locale('en')}) => MaterialApp(
  locale: locale,
  supportedLocales: const [Locale('en'), Locale('zh')],
  localizationsDelegates: GlobalMaterialLocalizations.delegates,
  home: Scaffold(body: child),
);

Widget _boundaries({bool first = true, bool second = true}) => _app(
  Column(
    children: [
      if (first)
        const Expanded(
          key: ValueKey('first'),
          child: ErrorBoundary(
            label: 'First failure',
            child: Text('First child'),
          ),
        ),
      if (second)
        const Expanded(
          key: ValueKey('second'),
          child: ErrorBoundary(
            label: 'Second failure',
            child: Text('Second child'),
          ),
        ),
    ],
  ),
);

Future<void> _flushError(WidgetTester tester) async {
  await tester.pump();
  await tester.pump();
}

class _ErrorHooks {
  final errors = <FlutterErrorDetails>[];
  final presentations = <FlutterErrorDetails>[];

  late final FlutterExceptionHandler appHandler = _report;

  void _report(FlutterErrorDetails details) {
    errors.add(details);
    FlutterError.presentError(details);
  }
}

Future<void> _withErrorHooks(
  WidgetTester tester,
  Future<void> Function(_ErrorHooks hooks) run,
) async {
  final original = FlutterError.onError;
  final originalPresentation = FlutterError.presentError;
  final hooks = _ErrorHooks();
  FlutterError.onError = hooks.appHandler;
  FlutterError.presentError = hooks.presentations.add;
  try {
    await run(hooks);
  } finally {
    try {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    } finally {
      FlutterError.onError = original;
      FlutterError.presentError = originalPresentation;
    }
  }
}
