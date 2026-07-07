import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

/// Shown while the app is verifying the session on startup, before
/// GoRouter knows whether to land on `/login` or `/dashboard`.
///
/// Always renders in dark mode regardless of system theme, matching the
/// native launch splash so there's no light-to-dark flash on handoff.
class AppSplash extends StatefulWidget {
  const AppSplash({super.key});

  @override
  State<AppSplash> createState() => _AppSplashState();
}

class _AppSplashState extends State<AppSplash>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkPageBg,
      body: Center(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final breathe = 0.97 + 0.03 * math.sin(_controller.value * 2 * math.pi);
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Transform.scale(
                  scale: breathe,
                  child: Image.asset(
                    'assets/images/s-logo-native-splash.png',
                    width: 112,
                    height: 112,
                  ),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: 96,
                  height: 3,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: CustomPaint(
                      painter: _ShimmerBarPainter(progress: _controller.value),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// A slim indeterminate progress bar: a soft track with a bright highlight
/// that sweeps left-to-right on a loop.
class _ShimmerBarPainter extends CustomPainter {
  _ShimmerBarPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final trackPaint = Paint()..color = Colors.white.withOpacity(0.08);
    canvas.drawRect(Offset.zero & size, trackPaint);

    final sweep = ((progress * 1.4) % 1.0).clamp(0.0, 1.0);
    final highlightCenter = -0.3 + sweep * 1.6;

    final highlightPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          AppColors.primary.withOpacity(0),
          AppColors.primary,
          AppColors.primary.withOpacity(0),
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(
        Rect.fromLTWH(
          (highlightCenter - 0.3) * size.width,
          0,
          size.width * 0.6,
          size.height,
        ),
      );
    canvas.drawRect(Offset.zero & size, highlightPaint);
  }

  @override
  bool shouldRepaint(covariant _ShimmerBarPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
