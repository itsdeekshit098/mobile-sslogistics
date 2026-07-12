import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/theme/theme_extensions.dart';

/// A shimmering placeholder box. Building block for skeleton screens.
class SkeletonBox extends StatelessWidget {
  final double width;
  final double height;
  final BorderRadius borderRadius;

  const SkeletonBox({
    super.key,
    this.width = double.infinity,
    required this.height,
    this.borderRadius = const BorderRadius.all(Radius.circular(6)),
  });

  const SkeletonBox.circle({super.key, required double size})
      : width = size,
        height = size,
        borderRadius = const BorderRadius.all(Radius.circular(1000));

  @override
  Widget build(BuildContext context) {
    // Deliberately darker than AppColors.border (#E2E8F0) — that shade is
    // nearly invisible against the white card / near-white page background
    // this sits on. slate-300 gives enough contrast to actually read as a
    // placeholder shape rather than disappearing.
    final base = context.isDark ? AppColors.darkTextMuted.withValues(alpha: 0.35) : const Color(0xFFCBD5E1);
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(color: base, borderRadius: borderRadius),
    );
  }
}

/// Wraps skeleton content with a moving shimmer sweep. Hand-rolled (no
/// `shimmer` package dependency) so it matches the app's light/dark colors.
class Shimmer extends StatefulWidget {
  final Widget child;

  const Shimmer({super.key, required this.child});

  @override
  State<Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<Shimmer> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final highlight =
        context.isDark ? AppColors.darkTextMuted.withValues(alpha: 0.25) : Colors.white.withValues(alpha: 0.6);
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            final dx = _controller.value * 2 - 1;
            return LinearGradient(
              begin: Alignment(dx - 1, 0),
              end: Alignment(dx, 0),
              colors: [Colors.transparent, highlight, Colors.transparent],
            ).createShader(bounds);
          },
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

/// Shape of card the skeleton row should mimic.
enum SkeletonCardShape {
  /// Circular leading avatar + title/chip row + a couple of info lines.
  /// Matches DriverCard / OwnerCard / TechnicianCard / SessionUserCard.
  avatar,

  /// No avatar, title/chip row + info lines only. Matches WarrantyCard /
  /// ActivityLogCard.
  plain,

  /// Left accent stripe + two-column top row + a bottom "band" row of
  /// figures. Matches RepairCard / ExternalTripCard / TripBookingCard.
  band,
}

/// Skeleton placeholder for a list of card rows shaped like one of the
/// app's standard entity cards. Pick [shape] to match the real card widget
/// the list will render once data loads.
class SkeletonListCards extends StatelessWidget {
  final int itemCount;
  final int infoLines;
  final SkeletonCardShape shape;
  final EdgeInsets padding;

  const SkeletonListCards({
    super.key,
    this.itemCount = 6,
    this.infoLines = 2,
    this.shape = SkeletonCardShape.avatar,
    this.padding = const EdgeInsets.only(top: 8, bottom: 8),
  });

  @override
  Widget build(BuildContext context) {
    return Shimmer(
      child: ListView.builder(
        padding: padding,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: itemCount,
        itemBuilder: (context, i) => _SkeletonCard(infoLines: infoLines, shape: shape),
      ),
    );
  }
}

class _SkeletonCard extends StatelessWidget {
  final int infoLines;
  final SkeletonCardShape shape;

  const _SkeletonCard({required this.infoLines, required this.shape});

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    final cardColor = isDark ? AppColors.darkCardBg : Colors.white;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.border;

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: SkeletonBox(height: 14, borderRadius: BorderRadius.circular(4))),
            const SizedBox(width: 8),
            SkeletonBox(width: 46, height: 18, borderRadius: BorderRadius.circular(9)),
          ],
        ),
        for (var i = 0; i < infoLines; i++) ...[
          const SizedBox(height: 8),
          SkeletonBox(
            width: i.isEven ? 140 : 100,
            height: 11,
            borderRadius: BorderRadius.circular(4),
          ),
        ],
        if (shape == SkeletonCardShape.band) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              for (var i = 0; i < 3; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(child: SkeletonBox(height: 34, borderRadius: BorderRadius.circular(8))),
              ],
            ],
          ),
        ],
      ],
    );

    final body = shape == SkeletonCardShape.avatar
        ? Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SkeletonBox.circle(size: 44),
              const SizedBox(width: 12),
              Expanded(child: content),
            ],
          )
        : content;

    // Accent stripe (band shape) is a separately-positioned rounded box,
    // not a stretched Row child — a Row with CrossAxisAlignment.stretch
    // inside a ListView item receives an unbounded height constraint and
    // crashes layout, and a non-uniform Border can't combine with
    // borderRadius either. Stack + Positioned.fill has neither problem.
    final stripeColor = context.isDark ? AppColors.darkTextMuted.withValues(alpha: 0.35) : const Color(0xFFCBD5E1);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          if (shape == SkeletonCardShape.band)
            Positioned(left: 0, top: 0, bottom: 0, width: 4, child: ColoredBox(color: stripeColor)),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: body,
          ),
        ],
      ),
    );
  }
}
