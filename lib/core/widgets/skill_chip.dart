import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_typography.dart';

enum SkillIntent { teach, learn, neutral }

class SkillChip extends StatelessWidget {
  final String label;
  final SkillIntent intent;
  final String? level;
  final VoidCallback? onTap;
  final VoidCallback? onDeleted;
  final bool isSelected;

  const SkillChip({
    super.key,
    required this.label,
    this.intent = SkillIntent.neutral,
    this.level,
    this.onTap,
    this.onDeleted,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color border;
    Color text;

    switch (intent) {
      case SkillIntent.teach:
        bg = isSelected
            ? AppColors.primaryBlue
            : AppColors.primaryBlue.withOpacity(0.12);
        border = isSelected
            ? AppColors.primaryBlue
            : AppColors.primaryBlue.withOpacity(0.35);
        text = isSelected ? Colors.white : AppColors.primaryBlue;
        break;
      case SkillIntent.learn:
        bg = isSelected
            ? AppColors.secondaryViolet
            : AppColors.secondaryViolet.withOpacity(0.12);
        border = isSelected
            ? AppColors.secondaryViolet
            : AppColors.secondaryViolet.withOpacity(0.35);
        text = isSelected ? Colors.white : AppColors.secondaryViolet;
        break;
      case SkillIntent.neutral:
        bg = isSelected ? AppColors.primaryBlue : AppColors.cardElevated;
        border = isSelected ? AppColors.primaryBlue : AppColors.border;
        text = isSelected ? Colors.white : AppColors.textPrimary;
        break;
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: border, width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (intent == SkillIntent.teach) ...[
              const Icon(
                Icons.school_outlined,
                size: 14,
                color: AppColors.primaryBlue,
              ),
              const SizedBox(width: 5),
            ] else if (intent == SkillIntent.learn) ...[
              const Icon(
                Icons.lightbulb_outline,
                size: 14,
                color: AppColors.secondaryViolet,
              ),
              const SizedBox(width: 5),
            ],
            Text(
              label,
              style: AppTypography.chip.copyWith(
                color: text,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (level != null) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: AppColors.background.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  level!.toUpperCase(),
                  style: AppTypography.caption.copyWith(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: text,
                  ),
                ),
              ),
            ],
            if (onDeleted != null) ...[
              const SizedBox(width: 6),
              GestureDetector(
                onTap: onDeleted,
                child: Icon(
                  Icons.close,
                  size: 14,
                  color: text.withOpacity(0.8),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
