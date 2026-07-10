import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_icons.dart';
import '../data/settings_models.dart';
import 'settings_status_banner.dart';

class AppVersionCard extends StatefulWidget {
  final AppVersionSettings settings;
  final Future<void> Function({int? minAndroidVersionCode, String? message}) onSave;

  const AppVersionCard({super.key, required this.settings, required this.onSave});

  @override
  State<AppVersionCard> createState() => _AppVersionCardState();
}

class _AppVersionCardState extends State<AppVersionCard> {
  late final _versionCtrl =
      TextEditingController(text: widget.settings.minAndroidVersionCode?.toString() ?? '');
  late final _messageCtrl = TextEditingController(text: widget.settings.message);
  bool _saving = false;

  @override
  void dispose() {
    _versionCtrl.dispose();
    _messageCtrl.dispose();
    super.dispose();
  }

  bool get _dirty =>
      _versionCtrl.text.trim() != (widget.settings.minAndroidVersionCode?.toString() ?? '') ||
      _messageCtrl.text.trim() != widget.settings.message;

  int? get _parsedVersionCode {
    final raw = _versionCtrl.text.trim();
    return raw.isEmpty ? null : int.tryParse(raw);
  }

  bool get _isValidVersionCode {
    final raw = _versionCtrl.text.trim();
    if (raw.isEmpty) return true;
    final parsed = int.tryParse(raw);
    return parsed != null && parsed > 0;
  }

  Future<void> _save(int? versionCode) async {
    setState(() => _saving = true);
    try {
      await widget.onSave(minAndroidVersionCode: versionCode, message: _messageCtrl.text.trim());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('App version settings saved'), backgroundColor: AppColors.success),
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
    final isOn = widget.settings.minAndroidVersionCode != null;
    InputDecoration decor(String hint) => InputDecoration(
          hintText: hint,
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
        );

    TextStyle labelStyle() => TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
          color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
        );

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
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
              Icon(AppIcons.uploadCloud, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Force App Update',
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
            'Blocks the Android app with a non-dismissible update popup for anyone on a build '
            'older than the minimum version code below. Leave blank to disable enforcement.',
            style: TextStyle(
              fontSize: 12.5,
              color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          SettingsStatusBanner(
            isOn: isOn,
            text: isOn
                ? 'Force update is ON — builds below versionCode ${widget.settings.minAndroidVersionCode} are blocked.'
                : 'Force update is OFF — no minimum version enforced.',
          ),
          const SizedBox(height: 12),
          Text('Minimum Android versionCode', style: labelStyle()),
          const SizedBox(height: 6),
          TextField(
            controller: _versionCtrl,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onChanged: (_) => setState(() {}),
            decoration: decor('e.g. 5'),
          ),
          if (!_isValidVersionCode) ...[
            const SizedBox(height: 4),
            const Text(
              'Must be a positive whole number, or blank.',
              style: TextStyle(fontSize: 12, color: AppColors.error),
            ),
          ],
          const SizedBox(height: 10),
          Text('Message shown to users (optional)', style: labelStyle()),
          const SizedBox(height: 6),
          TextField(
            controller: _messageCtrl,
            maxLines: 2,
            onChanged: (_) => setState(() {}),
            decoration: decor('A new version is available. Please update to continue.'),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: (_dirty && !_saving && _isValidVersionCode)
                  ? () => _save(_parsedVersionCode)
                  : null,
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                    )
                  : const Text('Save'),
            ),
          ),
          if (isOn) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saving ? null : () => _save(null),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
                child: const Text('Clear (disable enforcement)'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
