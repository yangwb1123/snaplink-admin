import 'package:flutter/material.dart';

/// Responsive, keyboard-safe shell shared by the public entry surfaces.
///
/// The compact padding keeps form controls usable on narrow phones while the
/// scroll view prevents the software keyboard or large text from clipping the
/// final action.
class ResponsiveEntryCard extends StatelessWidget {
  final Widget child;
  final double maxWidth;

  const ResponsiveEntryCard({
    super.key,
    required this.child,
    this.maxWidth = 440,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 400;
          final outer = compact ? 12.0 : 24.0;
          final inner = compact ? 20.0 : 28.0;
          final minHeight = constraints.hasBoundedHeight
              ? (constraints.maxHeight - outer * 2).clamp(0.0, double.infinity)
              : 0.0;
          return SingleChildScrollView(
            padding: EdgeInsets.all(outer),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: minHeight),
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxWidth),
                  child: Card(
                    child: Padding(
                      padding: EdgeInsets.all(inner),
                      child: child,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
