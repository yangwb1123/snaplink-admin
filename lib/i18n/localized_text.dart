import 'package:flutter/material.dart';

import '../app_settings.dart';
import 'app_strings.dart';

/// Drop-in [Text] equivalent for canonical application copy.
///
/// Values from APIs, resource identifiers, and user input should keep using
/// [Text]. Literal interface copy uses this widget so feature files do not
/// need to repeat locale lookup boilerplate.
class LocalizedText extends StatelessWidget {
  final String data;
  final TextStyle? style;
  final StrutStyle? strutStyle;
  final TextAlign? textAlign;
  final TextDirection? textDirection;
  final Locale? locale;
  final bool? softWrap;
  final TextOverflow? overflow;
  final TextScaler? textScaler;
  final int? maxLines;
  final String? semanticsLabel;
  final TextWidthBasis? textWidthBasis;
  final TextHeightBehavior? textHeightBehavior;
  final Color? selectionColor;

  const LocalizedText(
    this.data, {
    super.key,
    this.style,
    this.strutStyle,
    this.textAlign,
    this.textDirection,
    this.locale,
    this.softWrap,
    this.overflow,
    this.textScaler,
    this.maxLines,
    this.semanticsLabel,
    this.textWidthBasis,
    this.textHeightBehavior,
    this.selectionColor,
  });

  @override
  Widget build(BuildContext context) => Text(
    context.tr(data),
    style: style,
    strutStyle: strutStyle,
    textAlign: textAlign,
    textDirection: textDirection,
    locale: locale,
    softWrap: softWrap,
    overflow: overflow,
    textScaler: textScaler,
    maxLines: maxLines,
    semanticsLabel: semanticsLabel == null ? null : context.tr(semanticsLabel!),
    textWidthBasis: textWidthBasis,
    textHeightBehavior: textHeightBehavior,
    selectionColor: selectionColor,
  );
}

/// For static string properties such as [InputDecoration.labelText].
///
/// The root app rebuilds whenever [AppSettings.locale] changes, so this value
/// is re-evaluated for every locale switch.
extension LocalizedSourceString on String {
  String get localized =>
      AppStrings.forLocale(AppSettings.instance.locale).translate(this);
}
