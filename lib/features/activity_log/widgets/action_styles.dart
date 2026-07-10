import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_icons.dart';

/// Icon + color for an activity log action, resolved via a small set of
/// explicit entries (mirrors the web's `ACTION_STYLES`) with a prefix-based
/// fallback so newly-added `AuditAction` values never render as a blank row.
class ActionStyle {
  final IconData icon;
  final Color color;

  const ActionStyle({required this.icon, required this.color});
}

const Map<String, ActionStyle> _explicitStyles = {
  'CREATE_VEHICLE': ActionStyle(icon: AppIcons.plus, color: AppColors.success),
  'BAN_USER': ActionStyle(icon: AppIcons.ban, color: AppColors.error),
  'UNBAN_USER': ActionStyle(icon: AppIcons.checkCircle, color: AppColors.success),
  'REVOKE_SESSIONS': ActionStyle(icon: AppIcons.shield, color: AppColors.warning),
  'RESET_PASSWORD': ActionStyle(icon: AppIcons.key, color: AppColors.warning),
};

const Map<String, String> _explicitLabels = {
  'BAN_USER': 'Banned User',
  'UNBAN_USER': 'Unbanned User',
  'REVOKE_SESSIONS': 'Revoked Sessions',
  'RESET_PASSWORD': 'Reset Password',
  'ENABLE_MAINTENANCE_MODE': 'Enabled Maintenance Mode',
  'DISABLE_MAINTENANCE_MODE': 'Disabled Maintenance Mode',
  'SET_MIN_APP_VERSION': 'Set Minimum App Version',
};

const Map<String, String> _verbLabels = {
  'CREATE': 'Created',
  'UPDATE': 'Updated',
  'DELETE': 'Deleted',
  'UPLOAD': 'Uploaded',
};

ActionStyle resolveActionStyle(String action) {
  final explicit = _explicitStyles[action];
  if (explicit != null) return explicit;

  if (action.startsWith('CREATE_') || action.startsWith('UPLOAD_')) {
    return const ActionStyle(icon: AppIcons.plus, color: AppColors.success);
  }
  if (action.startsWith('UPDATE_')) {
    return const ActionStyle(icon: AppIcons.pencil, color: AppColors.primary);
  }
  if (action.startsWith('DELETE_')) {
    return const ActionStyle(icon: AppIcons.trash2, color: AppColors.error);
  }
  if (action.startsWith('BAN_') ||
      action.startsWith('REVOKE_') ||
      action.startsWith('ENABLE_MAINTENANCE') ||
      action.startsWith('SET_MIN_APP_VERSION')) {
    return const ActionStyle(icon: AppIcons.alertTriangle, color: AppColors.warning);
  }
  return const ActionStyle(icon: AppIcons.activity, color: AppColors.textMuted);
}

String actionLabel(String action) {
  final explicit = _explicitLabels[action];
  if (explicit != null) return explicit;

  final parts = action.split('_');
  if (parts.length > 1 && _verbLabels.containsKey(parts.first)) {
    final verb = _verbLabels[parts.first]!;
    final rest = parts
        .sublist(1)
        .map((w) => w.isEmpty ? w : '${w[0]}${w.substring(1).toLowerCase()}')
        .join(' ');
    return '$verb $rest';
  }

  // Fallback: title-case every word.
  return parts
      .map((w) => w.isEmpty ? w : '${w[0]}${w.substring(1).toLowerCase()}')
      .join(' ');
}
