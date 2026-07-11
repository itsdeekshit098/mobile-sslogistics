import 'package:flutter/material.dart';

/// Collapses the `Theme.of(context).brightness == Brightness.dark` /
/// `Theme.of(context).colorScheme` boilerplate repeated across the app's
/// (mostly hand-rolled, not Theme-driven) dark-mode conditionals.
extension ThemeContextX on BuildContext {
  bool get isDark => Theme.of(this).brightness == Brightness.dark;
  ColorScheme get colors => Theme.of(this).colorScheme;
}
