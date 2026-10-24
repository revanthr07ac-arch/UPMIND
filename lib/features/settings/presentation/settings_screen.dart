import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/widgets/custom_button.dart';
import '../../../core/widgets/custom_card.dart';
import '../../auth/data/auth_repository.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  void _showDeleteAccountDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Delete Account',
          style: AppTypography.h3.copyWith(color: AppColors.error),
        ),
        content: Text(
          'Are you sure you want to delete your UPMIND account? All your posts, tutorials, and profile data will be permanently removed. This action cannot be undone.',
          style: AppTypography.bodySecondary,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () async {
              Navigator.pop(ctx);
              await ref.read(authNotifierProvider.notifier).deleteAccount();
              if (context.mounted) {
                context.go('/login');
              }
            },
            child: const Text('Delete Permanently'),
          ),
        ],
      ),
    );
  }

  void _showCommunityGuidelines(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Community Guidelines', style: AppTypography.h3),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '1. Respect & Growth',
                style: AppTypography.bodyMedium.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'UPMIND is a safe space for learning. Encourage beginners and provide constructive, supportive feedback.',
                style: AppTypography.caption,
              ),
              const SizedBox(height: 10),
              Text(
                '2. Authentic Skill Portfolios',
                style: AppTypography.bodyMedium.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'Showcase your own original work. Never impersonate or claim false expertise.',
                style: AppTypography.caption,
              ),
              const SizedBox(height: 10),
              Text(
                '3. Free & Open Learning',
                style: AppTypography.bodyMedium.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'No paid paywalls, scams, or monetization pitches. Knowledge sharing is peer-to-peer and accessible.',
                style: AppTypography.caption,
              ),
              const SizedBox(height: 10),
              Text(
                '4. Zero Tolerance for Harassment',
                style: AppTypography.bodyMedium.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'Hate speech, spam, harassment, and inappropriate content result in immediate account termination.',
                style: AppTypography.caption,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Understood'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authRepositoryProvider).currentUser;

    return Scaffold(
      appBar: AppBar(
        title: Text('Settings & Privacy', style: AppTypography.h3),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => context.pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Account Info
          CustomCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ACCOUNT DETAILS',
                  style: AppTypography.caption.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Email: ${user?.email ?? "Not signed in"}',
                  style: AppTypography.bodyMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  'User ID: ${user?.id ?? "—"}',
                  style: AppTypography.caption,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Community & Policies
          CustomCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(
                    Icons.verified_user_outlined,
                    color: AppColors.primaryBlue,
                  ),
                  title: const Text('Community Guidelines'),
                  trailing: const Icon(
                    Icons.chevron_right,
                    color: AppColors.textMuted,
                  ),
                  onTap: () => _showCommunityGuidelines(context),
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(
                    Icons.security_outlined,
                    color: AppColors.secondaryViolet,
                  ),
                  title: const Text('Safety & Moderation Policy'),
                  trailing: const Icon(
                    Icons.chevron_right,
                    color: AppColors.textMuted,
                  ),
                  onTap: () => _showCommunityGuidelines(context),
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(
                    Icons.info_outline,
                    color: AppColors.textSecondary,
                  ),
                  title: const Text('About UPMIND'),
                  subtitle: const Text('Version 1.0.0 (Release Candidate)'),
                  trailing: const Icon(
                    Icons.chevron_right,
                    color: AppColors.textMuted,
                  ),
                  onTap: () {},
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Sign Out Button
          CustomButton(
            text: 'Sign Out',
            variant: ButtonVariant.outline,
            icon: Icons.logout_rounded,
            onPressed: () async {
              await ref.read(authNotifierProvider.notifier).signOut();
              if (context.mounted) context.go('/login');
            },
          ),
          const SizedBox(height: 14),

          // Delete Account Button (Required by Apple/Google store policies & prompt Section 6)
          CustomButton(
            text: 'Delete Account',
            variant: ButtonVariant.destructive,
            icon: Icons.delete_forever_outlined,
            onPressed: () => _showDeleteAccountDialog(context, ref),
          ),
        ],
      ),
    );
  }
}
