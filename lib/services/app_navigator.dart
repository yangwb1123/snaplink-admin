import 'package:flutter/material.dart';

/// Navigator access for non-browser shells whose route changes cannot use
/// `window.location`.
abstract final class AppNavigator {
  static final key = GlobalKey<NavigatorState>();
}
