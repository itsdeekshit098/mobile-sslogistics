import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';

/// Amber "on" / green "off" status banner, mirroring the web settings
/// cards' status text (e.g. "Maintenance mode is ON — …").
class SettingsStatusBanner extends StatelessWidget {
  final bool isOn;
  final String text;

  const SettingsStatusBanner({super.key, required this.isOn, required this.text});

  @override
  Widget build(BuildContext context) {
    final color = isOn ? AppColors.warning : AppColors.success;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.32)),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }
}
