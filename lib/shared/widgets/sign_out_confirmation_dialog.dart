import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_icons.dart';
import '../../features/auth/providers/auth_provider.dart';

/// Confirmation dialog shown before signing out. Performs the sign-out
/// call itself (rather than just returning a bool to the caller, like
/// [DeleteConfirmationDialog] does) so it can show a loading state and
/// block dismissal while the request is in flight — otherwise a user
/// tapping outside the dialog or hitting back mid-logout could land back
/// on an authenticated screen with a half-torn-down session.
class SignOutConfirmationDialog extends ConsumerStatefulWidget {
  const SignOutConfirmationDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (_) => const SignOutConfirmationDialog(),
    );
  }

  @override
  ConsumerState<SignOutConfirmationDialog> createState() =>
      _SignOutConfirmationDialogState();
}

class _SignOutConfirmationDialogState
    extends ConsumerState<SignOutConfirmationDialog> {
  bool _signingOut = false;
  String? _error;

  Future<void> _confirm() async {
    setState(() {
      _signingOut = true;
      _error = null;
    });
    try {
      await ref.read(authProvider.notifier).logout();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _signingOut = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final dialogWidth = (size.width - 44).clamp(280.0, 360.0);
    final compact = size.width < 380;
    final buttonHeight = compact ? 48.0 : 52.0;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return PopScope(
      // Blocks the back gesture/button and the barrier tap while the
      // sign-out request is in flight, so a mistap can't leave the app
      // sitting mid-teardown on an authenticated screen.
      canPop: !_signingOut,
      child: Dialog(
        insetPadding: EdgeInsets.symmetric(
          horizontal: compact ? 16 : 22,
          vertical: 22,
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: dialogWidth),
          child: Container(
            padding: EdgeInsets.fromLTRB(
              compact ? 18 : 22,
              compact ? 20 : 22,
              compact ? 18 : 22,
              compact ? 18 : 22,
            ),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCardBg : Colors.white,
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.14),
                  blurRadius: 28,
                  offset: const Offset(0, 14),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: compact ? 66 : 78,
                  height: compact ? 66 : 78,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.07),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Container(
                      width: compact ? 50 : 58,
                      height: compact ? 50 : 58,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.13),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        AppIcons.logOut,
                        color: AppColors.primary,
                        size: 29,
                      ),
                    ),
                  ),
                ),
                SizedBox(height: compact ? 16 : 18),
                Text(
                  'Sign out?',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: isDark
                        ? AppColors.darkTextPrimary
                        : AppColors.textPrimary,
                    fontSize: compact ? 24 : 26,
                    height: 1.1,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  "You'll need to sign in again to access your account.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.textSecondary,
                    fontSize: compact ? 13.5 : 14.5,
                    height: 1.35,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkErrorBg : AppColors.errorBg,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppColors.error,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
                SizedBox(height: compact ? 16 : 18),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        // Disabled while signing out — the close/cancel
                        // path must not be usable mid-request.
                        onPressed: _signingOut
                            ? null
                            : () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          minimumSize: Size.fromHeight(buttonHeight),
                          foregroundColor: isDark
                              ? AppColors.darkTextSecondary
                              : AppColors.textSecondary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          side: BorderSide(
                            color: isDark
                                ? AppColors.darkBorder
                                : AppColors.border,
                          ),
                          textStyle: const TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _signingOut ? null : _confirm,
                        style: ElevatedButton.styleFrom(
                          minimumSize: Size.fromHeight(buttonHeight),
                          backgroundColor: AppColors.primary,
                          disabledBackgroundColor: AppColors.primary
                              .withValues(alpha: 0.6),
                          foregroundColor: Colors.white,
                          elevation: 8,
                          shadowColor: AppColors.primary.withValues(
                            alpha: 0.22,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          textStyle: const TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        child: _signingOut
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.4,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('Sign out'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
