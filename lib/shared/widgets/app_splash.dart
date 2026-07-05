import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

/// Shown while the app is verifying the session on startup, before
/// GoRouter knows whether to land on `/login` or `/dashboard`.
class AppSplash extends StatelessWidget {
  const AppSplash({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? AppColors.darkPageBg : AppColors.pageBg,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/images/s-logo-native-splash.png',
              width: 128,
              height: 128,
            ),
            const SizedBox(height: 24),
            const CircularProgressIndicator(
              color: AppColors.primary,
              strokeWidth: 3,
            ),
          ],
        ),
      ),
    );
  }
}
