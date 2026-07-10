import 'package:flutter/material.dart';

/// Pairs a widget's location with a way to ask "does this currently have a
/// validation error?" — works for both `Form`/`TextFormField` fields (via
/// `FormFieldState.hasError`) and manually-validated fields (a plain
/// boolean check), so the same scroll-to-error mechanism covers every form
/// in the app regardless of which validation style it uses.
class ValidatedField {
  final GlobalKey key;
  final bool Function() hasError;
  final FocusNode? focusNode;

  const ValidatedField({
    required this.key,
    required this.hasError,
    this.focusNode,
  });
}

/// Scrolls to and focuses the first field in [fields] (checked in order)
/// that currently has an error. Necessary because `Form.validate()` only
/// paints red borders/error text — it never brings an off-screen error
/// into view on its own. Returns whether an error was found.
Future<bool> scrollToFirstError(
  List<ValidatedField> fields, {
  double alignment = 0.2,
}) async {
  for (final field in fields) {
    if (field.hasError()) {
      final fieldContext = field.key.currentContext;
      if (fieldContext != null) {
        await Scrollable.ensureVisible(
          fieldContext,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
          alignment: alignment,
        );
      }
      field.focusNode?.requestFocus();
      return true;
    }
  }
  return false;
}

/// Number of fields in [fields] currently showing a validation error —
/// drives the count shown in [FormErrorBanner].
int countFormErrors(List<ValidatedField> fields) =>
    fields.where((f) => f.hasError()).length;
