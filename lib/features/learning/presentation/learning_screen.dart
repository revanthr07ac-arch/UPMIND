import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/widgets/custom_button.dart';
import '../../../core/widgets/custom_card.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/loading_indicator.dart';
import '../../../core/widgets/user_avatar.dart';
import '../data/learning_repository.dart';
import '../domain/learning_request_model.dart';

class LearningScreen extends ConsumerStatefulWidget {
  const LearningScreen({super.key});

  @override
  ConsumerState<LearningScreen> createState() => _LearningScreenState();
}

class _LearningScreenState extends ConsumerState<LearningScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<LearningRequestModel> _incoming = [];
  List<LearningRequestModel> _outgoing = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadRequests();
  }

  Future<void> _loadRequests() async {
    setState(() => _isLoading = true);
    final repo = ref.read(learningRepositoryProvider);
    final inc = await repo.getIncomingRequests();
    final out = await repo.getOutgoingRequests();
    if (mounted) {
      setState(() {
        _incoming = inc;
        _outgoing = out;
        _isLoading = false;
      });
    }
  }

  Future<void> _handleStatusUpdate(String id, String status) async {
    await ref.read(learningRepositoryProvider).updateRequestStatus(id, status);
    _loadRequests();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Request $status'),
          backgroundColor: status == 'accepted'
              ? AppColors.success
              : AppColors.cardElevated,
        ),
      );
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Learning Hub', style: AppTypography.h3),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primaryBlue,
          labelColor: AppColors.primaryBlue,
          unselectedLabelColor: AppColors.textSecondary,
          tabs: [
            Tab(text: 'Teaching Requests (${_incoming.length})'),
            Tab(text: 'My Learning (${_outgoing.length})'),
          ],
        ),
      ),
      body: Column(
        children: [
          // AI Coach Banner Card
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: InkWell(
              onTap: () => context.push('/learning-coach'),
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1E284A), Color(0xFF2E1B4D)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppColors.secondaryViolet.withOpacity(0.4),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.secondaryViolet.withOpacity(0.12),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        gradient: AppColors.primaryGradient,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.auto_awesome,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                'AI Learning Coach',
                                style: AppTypography.h3.copyWith(fontSize: 16),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 5,
                                  vertical: 1,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.primaryBlue,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'GEMINI AI',
                                  style: AppTypography.caption.copyWith(
                                    fontSize: 8,
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Generate a personalized step-by-step roadmap for any skill',
                            style: AppTypography.caption.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.arrow_forward_ios,
                      color: AppColors.textSecondary,
                      size: 16,
                    ),
                  ],
                ),
              ),
            ),
          ),

          Expanded(
            child: _isLoading
                ? const LoadingIndicator()
                : TabBarView(
                    controller: _tabController,
                    children: [
                      // Tab 1: Incoming requests (where I teach)
                      _buildIncomingTab(),
                      // Tab 2: Outgoing requests (where I learn)
                      _buildOutgoingTab(),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildIncomingTab() {
    if (_incoming.isEmpty) {
      return const EmptyState(
        icon: Icons.school_outlined,
        title: 'No Teaching Requests',
        message: 'When learners request your guidance in skills you can teach, they will appear here.',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _incoming.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final req = _incoming[index];
        return CustomCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  UserAvatar(
                    name: req.learnerFullName,
                    imageUrl: req.learnerAvatarUrl,
                    radius: 18,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          req.learnerFullName,
                          style: AppTypography.bodyMedium.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          'Wants to learn • ${req.skillName}',
                          style: AppTypography.caption.copyWith(
                            color: AppColors.primaryBlue,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _buildStatusBadge(req.status),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '"${req.message}"',
                  style: AppTypography.bodySecondary.copyWith(
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                DateFormatter.timeAgo(req.createdAt),
                style: AppTypography.caption,
              ),
              if (req.isPending) ...[
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: CustomButton(
                        text: 'Accept',
                        variant: ButtonVariant.primary,
                        height: 38,
                        onPressed: () =>
                            _handleStatusUpdate(req.id, 'accepted'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: CustomButton(
                        text: 'Decline',
                        variant: ButtonVariant.outline,
                        height: 38,
                        onPressed: () =>
                            _handleStatusUpdate(req.id, 'declined'),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildOutgoingTab() {
    if (_outgoing.isEmpty) {
      return EmptyState(
        icon: Icons.lightbulb_outline,
        title: 'No Learning Requests',
        message: 'Explore the Discover tab to find mentors and send learning requests.',
        actionText: 'Explore Mentors',
        onAction: () => context.go('/discover'),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _outgoing.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final req = _outgoing[index];
        return CustomCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  UserAvatar(
                    name: req.teacherFullName,
                    imageUrl: req.teacherAvatarUrl,
                    radius: 18,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Mentor: ${req.teacherFullName}',
                          style: AppTypography.bodyMedium.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          'Skill: ${req.skillName}',
                          style: AppTypography.caption.copyWith(
                            color: AppColors.secondaryViolet,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _buildStatusBadge(req.status),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Your Goal: "${req.message}"',
                style: AppTypography.bodySecondary,
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    DateFormatter.timeAgo(req.createdAt),
                    style: AppTypography.caption,
                  ),
                  if (req.isPending)
                    TextButton(
                      onPressed: () => _handleStatusUpdate(req.id, 'cancelled'),
                      child: Text(
                        'Cancel Request',
                        style: AppTypography.caption.copyWith(
                          color: AppColors.error,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatusBadge(String status) {
    Color bg;
    Color fg;
    String label = status.toUpperCase();

    switch (status) {
      case 'accepted':
        bg = AppColors.successLight;
        fg = AppColors.success;
        break;
      case 'declined':
        bg = AppColors.errorLight;
        fg = AppColors.error;
        break;
      case 'cancelled':
        bg = AppColors.cardElevated;
        fg = AppColors.textMuted;
        break;
      default:
        bg = AppColors.warningLight;
        fg = AppColors.warning;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: AppTypography.caption.copyWith(
          color: fg,
          fontWeight: FontWeight.bold,
          fontSize: 10,
        ),
      ),
    );
  }
}
