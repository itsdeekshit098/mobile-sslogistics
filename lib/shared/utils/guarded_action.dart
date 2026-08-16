import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';

/// Runs a fire-and-forget confirm-dialog action (delete, reverse, ...) with
/// error feedback. Without this, a rejected request (e.g. a server-side
/// business rule) throws unobserved: the dialog has already closed, so the
/// user sees no error and the list just looks unchanged, with no indication
/// anything failed.
Future<void> runGuarded(BuildContext context, Future<void> Function() action) async {
  try {
    await action();
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(e.toString().replaceFirst('Exception: ', '')),
        backgroundColor: AppColors.error,
      ),
    );
  }
}
