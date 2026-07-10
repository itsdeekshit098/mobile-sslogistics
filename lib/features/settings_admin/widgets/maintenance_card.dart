import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_icons.dart';
import '../data/settings_models.dart';
import 'settings_status_banner.dart';

class MaintenanceCard extends StatefulWidget {
  final MaintenanceSettings settings;
  final Future<void> Function({required bool maintenanceMode, String? message}) onSave;

  const MaintenanceCard({super.key, required this.settings, required this.onSave});

  @override
  State<MaintenanceCard> createState() => _MaintenanceCardState();
}

class _MaintenanceCardState extends State<MaintenanceCard> {
  late final _messageCtrl = TextEditingController(text: widget.settings.message);
  bool _saving = false;

  @override
  void dispose() {
    _messageCtrl.dispose();
    super.dispose();
  }

  Future<bool> _confirmEnable() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            backgroundColor: isDark ? AppColors.darkCardBg : Colors.white,
            title: const Text('Enable maintenance mode?'),
            content: const Text(
              'This blocks all non-admin access on web and mobile until it is turned off again.',
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.warning),
                child: const Text('Enable'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _toggle() async {
    final next = !widget.settings.maintenanceMode;
    if (next) {
      final confirmed = await _confirmEnable();
      if (!confirmed) return;
    }
    setState(() => _saving = true);
    try {
      await widget.onSave(maintenanceMode: next, message: _messageCtrl.text.trim());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Maintenance settings saved'), backgroundColor: AppColors.success),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', '')),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isOn = widget.settings.maintenanceMode;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCardBg : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(AppIcons.wrench, size: 18, color: AppColors.warning),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Maintenance Mode',
                  style: TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w800,
                    color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            "Blocks all non-admin access on web and mobile immediately — use this before "
            "making risky changes so no one can act on stale data mid-change.",
            style: TextStyle(
              fontSize: 12.5,
              color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          SettingsStatusBanner(
            isOn: isOn,
            text: isOn
                ? 'Maintenance mode is ON — the app is blocked for everyone but admins.'
                : 'Maintenance mode is OFF — the app is live.',
          ),
          const SizedBox(height: 12),
          Text(
            'Message shown to users (optional)',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _messageCtrl,
            maxLines: 2,
            decoration: InputDecoration(
              hintText: "We're performing scheduled maintenance. Please check back shortly.",
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppColors.primary, width: 2),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saving ? null : _toggle,
              style: ElevatedButton.styleFrom(
                backgroundColor: isOn ? AppColors.primary : AppColors.error,
              ),
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                    )
                  : Text(isOn ? 'Turn maintenance mode off' : 'Turn maintenance mode on'),
            ),
          ),
        ],
      ),
    );
  }
}
