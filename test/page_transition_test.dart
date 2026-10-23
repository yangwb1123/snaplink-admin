import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sso_admin/widgets/page_transition.dart';

void main() {
  testWidgets('reduced motion switches keyed pages without elapsed time', (
    tester,
  ) async {
    await tester.pumpWidget(_page('first', disableAnimations: true));
    final firstState = tester.state(find.byType(_PageContent));
    await tester.pumpWidget(_page('second', disableAnimations: true));
    await tester.pump();

    _expectAtRest(tester, 'second');
    expect(find.text('first'), findsNothing);
    expect(tester.state(find.byType(_PageContent)), isNot(same(firstState)));
  });

  testWidgets('normal keyed switching preserves the 200ms fade and slide', (
    tester,
  ) async {
    await tester.pumpWidget(_page('first'));
    _expectAtRest(tester, 'first');
    final switcher = tester.widget<AnimatedSwitcher>(
      find.byType(AnimatedSwitcher),
    );
    expect(switcher.duration, const Duration(milliseconds: 200));
    expect(switcher.switchInCurve, Curves.easeOutCubic);
    expect(switcher.switchOutCurve, Curves.easeInCubic);

    await tester.pumpWidget(_page('second'));
    await tester.pump();
    expect(find.text('first'), findsOneWidget);
    expect(_fade(tester, 'second').opacity.value, 0);
    expect(_slide(tester, 'second').position.value, const Offset(0, 0.015));

    await tester.pump(const Duration(milliseconds: 100));
    final incoming = Curves.easeOutCubic.transform(0.5);
    final outgoing = Curves.easeInCubic.transform(0.5);
    expect(_fade(tester, 'second').opacity.value, closeTo(incoming, 1e-6));
    expect(_fade(tester, 'first').opacity.value, closeTo(outgoing, 1e-6));
    for (final name in ['first', 'second']) {
      final opacity = _fade(tester, name).opacity.value;
      expect(opacity, inExclusiveRange(0, 1));
      expect(
        _slide(tester, name).position.value.dy,
        closeTo(0.015 * (1 - Curves.easeOutCubic.transform(opacity)), 1e-6),
      );
      expect(
        _slide(tester, name).position.value.dy,
        inExclusiveRange(0, 0.015),
      );
    }

    await tester.pump(const Duration(milliseconds: 99));
    expect(find.text('first'), findsOneWidget);
    expect(_fade(tester, 'second').opacity.value, lessThan(1));
    await tester.pump(const Duration(milliseconds: 1));
    expect(_fade(tester, 'second').opacity.value, 1);
    expect(_slide(tester, 'second').position.value, Offset.zero);
    expect(_fade(tester, 'first').opacity.value, 0);
    // Flutter dismisses the outgoing entry on the first tick past the endpoint.
    await tester.pump(const Duration(microseconds: 1));
    await tester.pump();
    expect(find.text('first'), findsNothing);
    _expectAtRest(tester, 'second');
  });

  for (final reduced in [false, true]) {
    testWidgets('same page key updates in place (reduced motion: $reduced)', (
      tester,
    ) async {
      const key = ValueKey('unchanged-page');
      await tester.pumpWidget(
        _page('first', pageKey: key, disableAnimations: reduced),
      );
      final state = tester.state(find.byType(_PageContent));
      await tester.pumpWidget(
        _page('updated', pageKey: key, disableAnimations: reduced),
      );
      await tester.pump();

      expect(find.text('first'), findsNothing);
      expect(tester.state(find.byType(_PageContent)), same(state));
      expect(find.byType(FadeTransition), findsOneWidget);
      _expectAtRest(tester, 'updated');
    });

    testWidgets('keeps the top-centered Stack (reduced motion: $reduced)', (
      tester,
    ) async {
      await tester.pumpWidget(
        _page('first', disableAnimations: reduced, size: const Size(160, 100)),
      );
      final origin = tester.getTopLeft(find.byType(Stack));
      expect(tester.getSize(find.byType(Stack)), const Size(320, 240));
      expect(
        tester.getTopLeft(find.text('first')),
        origin + const Offset(80, 0),
      );

      await tester.pumpWidget(
        _page('second', disableAnimations: reduced, size: const Size(80, 40)),
      );
      await tester.pump();
      final stack = tester.widget<Stack>(find.byType(Stack));
      expect(stack.alignment, Alignment.topCenter);
      expect(stack.children, hasLength(reduced ? 1 : 2));
      expect(
        find.descendant(
          of: find.byWidget(stack.children.last),
          matching: find.text('second'),
        ),
        findsOneWidget,
      );
      if (!reduced) {
        expect(
          find.descendant(
            of: find.byWidget(stack.children.first),
            matching: find.text('first'),
          ),
          findsOneWidget,
        );
        await tester.pump(const Duration(milliseconds: 200));
        await tester.pump(const Duration(microseconds: 1));
        await tester.pump();
      }
      expect(
        tester.getTopLeft(find.text('second')),
        origin + const Offset(120, 0),
      );
      expect(find.text('first'), findsNothing);
      _expectAtRest(tester, 'second');
    });
  }

  testWidgets('mounted preference changes apply to subsequent switches', (
    tester,
  ) async {
    // Reuse the exact widget to verify the MediaQuery dependency, not merely
    // a parent-driven rebuild of PageTransition.
    const page = PageTransition(
      pageKey: ValueKey('first'),
      child: _PageContent(name: 'first'),
    );
    await tester.pumpWidget(_host(page));
    final transitionState = tester.state(find.byType(PageTransition));
    final firstState = tester.state(find.byType(_PageContent));
    await tester.pumpWidget(_host(page, disableAnimations: true));
    await tester.pump();
    expect(tester.state(find.byType(PageTransition)), same(transitionState));
    expect(tester.state(find.byType(_PageContent)), same(firstState));
    expect(
      tester.widget<AnimatedSwitcher>(find.byType(AnimatedSwitcher)).duration,
      Duration.zero,
    );
    _expectAtRest(tester, 'first');

    await tester.pumpWidget(_page('second', disableAnimations: true));
    await tester.pump();
    expect(find.text('first'), findsNothing);
    _expectAtRest(tester, 'second');
    final secondState = tester.state(find.byType(_PageContent));

    await tester.pumpWidget(_page('second'));
    await tester.pump();
    expect(tester.state(find.byType(_PageContent)), same(secondState));
    _expectAtRest(tester, 'second');
    await tester.pumpWidget(_page('third'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(_fade(tester, 'third').opacity.value, inExclusiveRange(0, 1));
    expect(_fade(tester, 'second').opacity.value, inExclusiveRange(0, 1));
    expect(
      _slide(tester, 'third').position.value.dy,
      inExclusiveRange(0, 0.015),
    );
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(microseconds: 1));
    await tester.pump();
    expect(find.text('second'), findsNothing);
    _expectAtRest(tester, 'third');
  });

  testWidgets(
    'enabling reduced motion finishes active transitions immediately',
    (tester) async {
      const page = PageTransition(
        pageKey: ValueKey('second'),
        child: _PageContent(name: 'second'),
      );
      await tester.pumpWidget(_page('first'));
      await tester.pumpWidget(_host(page));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      final secondState = tester.state(
        find.widgetWithText(_PageContent, 'second'),
      );
      expect(_fade(tester, 'second').opacity.value, inExclusiveRange(0, 1));
      expect(find.text('first'), findsOneWidget);

      await tester.pumpWidget(_host(page, disableAnimations: true));
      await tester.pump();
      expect(find.text('first'), findsNothing);
      expect(tester.state(find.byType(_PageContent)), same(secondState));
      _expectAtRest(tester, 'second');

      await tester.pumpWidget(_host(page));
      await tester.pump();
      expect(find.text('first'), findsNothing);
      expect(tester.state(find.byType(_PageContent)), same(secondState));
      _expectAtRest(tester, 'second');
    },
  );

  testWidgets('without MediaQuery the normal transition still works', (
    tester,
  ) async {
    await tester.pumpWidget(_page('first', disableAnimations: null));
    await tester.pumpWidget(_page('second', disableAnimations: null));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(_fade(tester, 'second').opacity.value, inExclusiveRange(0, 1));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(microseconds: 1));
    await tester.pump();
    expect(find.text('first'), findsNothing);
    _expectAtRest(tester, 'second');
  });
}

Widget _page(
  String name, {
  bool? disableAnimations = false,
  Key? pageKey,
  Size size = const Size(120, 80),
}) => _host(
  PageTransition(
    pageKey: pageKey ?? ValueKey(name),
    child: _PageContent(name: name, size: size),
  ),
  disableAnimations: disableAnimations,
);

Widget _host(Widget child, {bool? disableAnimations = false}) {
  final content = Center(
    child: SizedBox(width: 320, height: 240, child: child),
  );
  return Directionality(
    textDirection: TextDirection.ltr,
    child: disableAnimations == null
        ? content
        : MediaQuery(
            data: MediaQueryData(disableAnimations: disableAnimations),
            child: content,
          ),
  );
}

FadeTransition _fade(WidgetTester tester, String name) =>
    tester.widget<FadeTransition>(
      find.ancestor(of: find.text(name), matching: find.byType(FadeTransition)),
    );

SlideTransition _slide(WidgetTester tester, String name) =>
    tester.widget<SlideTransition>(
      find.ancestor(
        of: find.text(name),
        matching: find.byType(SlideTransition),
      ),
    );

void _expectAtRest(WidgetTester tester, String name) {
  expect(find.text(name), findsOneWidget);
  expect(_fade(tester, name).opacity.value, 1);
  expect(_slide(tester, name).position.value, Offset.zero);
  expect(tester.binding.transientCallbackCount, 0);
}

class _PageContent extends StatefulWidget {
  final String name;
  final Size size;

  const _PageContent({required this.name, this.size = const Size(120, 80)});

  @override
  State<_PageContent> createState() => _PageContentState();
}

class _PageContentState extends State<_PageContent> {
  @override
  Widget build(BuildContext context) => SizedBox(
    width: widget.size.width,
    height: widget.size.height,
    child: Text(widget.name),
  );
}
