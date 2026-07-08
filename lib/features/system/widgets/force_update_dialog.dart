import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_colors.dart';

const _playStoreUrl =
    'https://play.google.com/store/apps/details?id=com.sslogistics.mobile_sslogistics';

/// Non-dismissible: no cancel/later button, back button and tap-outside are
/// both blocked (see the showDialog call in app.dart and the PopScope here).
/// The only way out is tapping "Update Now", which opens the Play Store.
class ForceUpdateDialog extends StatelessWidget {
  final String? message;

  const ForceUpdateDialog({super.key, this.message});

  Future<void> _openPlayStore() async {
    final uri = Uri.parse(_playStoreUrl);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Dialog(
        backgroundColor: Colors.white,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 40, 28, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const _IconBadge(),
              const SizedBox(height: 28),
              const Text(
                'Update Required',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  height: 1.15,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'A new version of the app is available with important improvements and bug fixes.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 15,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.pageBg,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.shield_outlined,
                        size: 18,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'For a better experience and security, please update the app to continue.',
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontSize: 13.5,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (message != null && message!.trim().isNotEmpty) ...[
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    message!,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _openPlayStore,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Update Now',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(width: 6),
                      Icon(Icons.chevron_right_rounded, size: 22),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.lock_outline_rounded,
                      size: 13, color: Colors.grey.shade500),
                  const SizedBox(width: 6),
                  Text(
                    "You'll be redirected to the Play Store",
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 12.5),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IconBadge extends StatelessWidget {
  const _IconBadge();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 150,
      height: 110,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            top: 6,
            left: 18,
            child: _Ring(size: 12, color: AppColors.primary.withValues(alpha: 0.35)),
          ),
          Positioned(
            top: 34,
            right: 6,
            child: Icon(Icons.auto_awesome_rounded,
                size: 18, color: AppColors.primary.withValues(alpha: 0.35)),
          ),
          Positioned(
            top: 2,
            right: 34,
            child: Icon(Icons.auto_awesome_rounded,
                size: 12, color: AppColors.primary.withValues(alpha: 0.3)),
          ),
          Positioned(
            bottom: 12,
            left: 40,
            child: Icon(Icons.circle,
                size: 6, color: AppColors.primary.withValues(alpha: 0.25)),
          ),
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.file_download_outlined,
              size: 36,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }
}

class _Ring extends StatelessWidget {
  final double size;
  final Color color;

  const _Ring({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 2),
      ),
    );
  }
}
