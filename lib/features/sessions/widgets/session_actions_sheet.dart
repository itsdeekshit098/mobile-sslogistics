import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_icons.dart';
import '../../../shared/widgets/delete_confirmation_dialog.dart';
import '../data/session_models.dart';
import 'reset_password_sheet.dart';

/// Actions bottom sheet for a user row: reset password, revoke sessions,
/// ban/unban. Self-actions are disabled here so the user never has to hit
/// the backend's "cannot act on your own account" guard to find out.
class SessionActionsSheet extends StatelessWidget {
  final SessionUser user;
  final bool isSelf;
  final Future<void> Function() onRevoke;
  final Future<void> Function() onToggleBan;
  final Future<bool> Function(String newPassword) onResetPassword;

  const SessionActionsSheet({
    super.key,
    required this.user,
    required this.isSelf,
    required this.onRevoke,
    required this.onToggleBan,
    required this.onResetPassword,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: isDark ? AppColors.darkCardBg : Colors.white,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkBorder : AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  user.label,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            _ActionTile(
              icon: AppIcons.key,
              label: 'Reset Password',
              color: AppColors.warning,
              disabled: isSelf,
              subtitle: isSelf ? 'You cannot reset your own password here' : null,
              onTap: () {
                Navigator.pop(context);
                _showResetPassword(context);
              },
            ),
            _ActionTile(
              icon: AppIcons.logOut,
              label: 'Revoke All Sessions',
              color: AppColors.error,
              disabled: isSelf,
              subtitle: isSelf ? 'You cannot revoke your own sessions' : null,
              onTap: () {
                Navigator.pop(context);
                _confirmRevoke(context);
              },
            ),
            _ActionTile(
              icon: user.isBanned ? AppIcons.checkCircle : AppIcons.ban,
              label: user.isBanned ? 'Unban User' : 'Ban User',
              color: user.isBanned ? AppColors.success : AppColors.error,
              disabled: isSelf,
              subtitle: isSelf ? 'You cannot ban your own account' : null,
              onTap: () {
                Navigator.pop(context);
                user.isBanned ? onToggleBan() : _confirmBan(context);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showResetPassword(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ResetPasswordSheet(
        user: user,
        onSubmit: (password) async {
          final revoked = await onResetPassword(password);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  revoked ? 'Password reset — sessions revoked' : 'Password reset',
                ),
                backgroundColor: AppColors.success,
              ),
            );
          }
        },
      ),
    );
  }

  void _confirmRevoke(BuildContext context) {
    showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => DeleteConfirmationDialog(
        title: 'Revoke All Sessions',
        targetName: user.label,
        warningText: 'This immediately signs the user out everywhere.',
        warningSubtext: 'They will need to log in again to continue using the app.',
        confirmLabel: 'Revoke',
        onConfirm: onRevoke,
      ),
    );
  }

  void _confirmBan(BuildContext context) {
    showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => DeleteConfirmationDialog(
        title: 'Ban User',
        targetName: user.label,
        warningText: 'This blocks the user from signing in.',
        warningSubtext: 'You can unban them again at any time.',
        confirmLabel: 'Ban',
        onConfirm: onToggleBan,
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool disabled;
  final String? subtitle;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.disabled = false,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final effectiveColor = disabled ? (isDark ? AppColors.darkTextMuted : AppColors.textMuted) : color;
    return ListTile(
      enabled: !disabled,
      leading: Icon(icon, color: effectiveColor),
      title: Text(label, style: TextStyle(color: effectiveColor, fontWeight: FontWeight.w600)),
      subtitle: subtitle != null
          ? Text(
              subtitle!,
              style: TextStyle(fontSize: 11.5, color: isDark ? AppColors.darkTextMuted : AppColors.textMuted),
            )
          : null,
      onTap: disabled ? null : onTap,
    );
  }
}
