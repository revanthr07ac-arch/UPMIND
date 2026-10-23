import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_typography.dart';

class UpmindLogo extends StatelessWidget {
  final double size;
  final bool showTagline;
  final bool isHorizontal;

  const UpmindLogo({
    super.key,
    this.size = 48,
    this.showTagline = true,
    this.isHorizontal = false,
  });

  @override
  Widget build(BuildContext context) {
    final iconWidget = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(size * 0.28),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryBlue.withOpacity(0.35),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Center(
        child: Icon(Icons.auto_awesome, color: Colors.white, size: size * 0.55),
      ),
    );

    final titleWidget = Text(
      'UPMIND',
      style: AppTypography.h1.copyWith(
        fontSize: size * 0.55,
        letterSpacing: 2.0,
        fontWeight: FontWeight.w800,
        foreground: Paint()
          ..shader = const LinearGradient(
            colors: [Color(0xFFF5F7FF), Color(0xFFC7D2FE)],
          ).createShader(Rect.fromLTWH(0, 0, size * 4, size)),
      ),
    );

    final taglineWidget = Text(
      'Showcase Skills. Share Knowledge. Grow Together.',
      style: AppTypography.caption.copyWith(
        color: AppColors.textSecondary,
        fontSize: 11,
      ),
      textAlign: TextAlign.center,
    );

    if (isHorizontal) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          iconWidget,
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [titleWidget, if (showTagline) taglineWidget],
          ),
        ],
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        iconWidget,
        const SizedBox(height: 14),
        titleWidget,
        if (showTagline) ...[const SizedBox(height: 6), taglineWidget],
      ],
    );
  }
}
