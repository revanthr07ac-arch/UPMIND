import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/widgets/custom_button.dart';
import '../../../core/widgets/custom_card.dart';
import '../../../core/widgets/custom_text_field.dart';
import '../../../core/widgets/loading_indicator.dart';
import '../data/learning_repository.dart';
import '../domain/roadmap_model.dart';

class LearningCoachScreen extends ConsumerStatefulWidget {
  const LearningCoachScreen({super.key});

  @override
  ConsumerState<LearningCoachScreen> createState() =>
      _LearningCoachScreenState();
}

class _LearningCoachScreenState extends ConsumerState<LearningCoachScreen> {
  final _skillController = TextEditingController(text: 'Flutter & Dart');
  final _goalController = TextEditingController(
    text: 'Build and launch my first production mobile app on Android & iOS',
  );

  String _level = 'beginner';
  int _weeklyHours = 10;
  String _pace = 'steady';

  bool _isGenerating = false;
  RoadmapModel? _generatedRoadmap;
  final Set<int> _completedStages = {};

  @override
  void dispose() {
    _skillController.dispose();
    _goalController.dispose();
    super.dispose();
  }

  Future<void> _generateRoadmap() async {
    final skill = _skillController.text.trim();
    final goal = _goalController.text.trim();

    if (skill.isEmpty || goal.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please specify both skill and your learning goal'),
        ),
      );
      return;
    }

    setState(() {
      _isGenerating = true;
      _generatedRoadmap = null;
    });

    try {
      final roadmap = await ref
          .read(learningRepositoryProvider)
          .generateRoadmap(
            skill: skill,
            level: _level,
            goal: goal,
            weeklyHours: _weeklyHours,
            pace: _pace,
          );

      if (mounted) {
        setState(() {
          _generatedRoadmap = roadmap;
          _isGenerating = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isGenerating = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to generate roadmap: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(
              Icons.auto_awesome,
              color: AppColors.secondaryViolet,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text('AI Learning Coach', style: AppTypography.h3),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Generator Form
            CustomCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Personalized Roadmap Generator',
                    style: AppTypography.h3,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Powered by Gemini AI to build tailored milestones and exercises',
                    style: AppTypography.caption,
                  ),
                  const SizedBox(height: 18),

                  // Target Skill
                  CustomTextField(
                    controller: _skillController,
                    label: 'SKILL TO LEARN',
                    hintText: 'e.g. Flutter, UI Design, Video Editing...',
                  ),
                  const SizedBox(height: 14),

                  // Current Level
                  Text(
                    'CURRENT EXPERIENCE LEVEL',
                    style: AppTypography.caption.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      _buildChoiceChip(
                        'Beginner',
                        'beginner',
                        _level,
                        (v) => setState(() => _level = v),
                      ),
                      const SizedBox(width: 8),
                      _buildChoiceChip(
                        'Intermediate',
                        'intermediate',
                        _level,
                        (v) => setState(() => _level = v),
                      ),
                      const SizedBox(width: 8),
                      _buildChoiceChip(
                        'Advanced',
                        'advanced',
                        _level,
                        (v) => setState(() => _level = v),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Learning Goal
                  CustomTextField(
                    controller: _goalController,
                    label: 'SPECIFIC LEARNING GOAL',
                    hintText: 'What concrete project or outcome do you want to accomplish?',
                    maxLines: 2,
                  ),
                  const SizedBox(height: 14),

                  // Study Time & Pace
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'WEEKLY HOURS',
                              style: AppTypography.caption.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 6),
                            DropdownButtonFormField<int>(
                              value: _weeklyHours,
                              dropdownColor: AppColors.cardElevated,
                              items: const [
                                DropdownMenuItem(
                                  value: 5,
                                  child: Text('5 hrs/week'),
                                ),
                                DropdownMenuItem(
                                  value: 10,
                                  child: Text('10 hrs/week'),
                                ),
                                DropdownMenuItem(
                                  value: 20,
                                  child: Text('20 hrs/week'),
                                ),
                              ],
                              onChanged: (val) =>
                                  setState(() => _weeklyHours = val ?? 10),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'LEARNING PACE',
                              style: AppTypography.caption.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 6),
                            DropdownButtonFormField<String>(
                              value: _pace,
                              dropdownColor: AppColors.cardElevated,
                              items: const [
                                DropdownMenuItem(
                                  value: 'relaxed',
                                  child: Text('Relaxed'),
                                ),
                                DropdownMenuItem(
                                  value: 'steady',
                                  child: Text('Steady'),
                                ),
                                DropdownMenuItem(
                                  value: 'intensive',
                                  child: Text('Intensive'),
                                ),
                              ],
                              onChanged: (val) =>
                                  setState(() => _pace = val ?? 'steady'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  CustomButton(
                    text: 'Generate AI Learning Roadmap',
                    icon: Icons.auto_awesome,
                    variant: ButtonVariant.secondary,
                    isLoading: _isGenerating,
                    onPressed: _generateRoadmap,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Roadmap Output
            if (_isGenerating) ...[
              Container(
                padding: const EdgeInsets.all(32),
                alignment: Alignment.center,
                child: const Column(
                  children: [
                    LoadingIndicator(size: 40),
                    SizedBox(height: 16),
                    Text(
                      'AI Coach is analyzing milestones & generating curriculum...',
                      style: TextStyle(color: AppColors.textSecondary),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ] else if (_generatedRoadmap != null) ...[
              _buildRoadmapView(_generatedRoadmap!),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildChoiceChip(
    String label,
    String value,
    String current,
    ValueChanged<String> onSelected,
  ) {
    final isSelected = value == current;
    return Expanded(
      child: InkWell(
        onTap: () => onSelected(value),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primaryBlue : AppColors.cardElevated,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? AppColors.primaryBlue : AppColors.border,
            ),
          ),
          child: Text(
            label,
            style: AppTypography.caption.copyWith(
              color: isSelected ? Colors.white : AppColors.textSecondary,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRoadmapView(RoadmapModel roadmap) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Summary Card
        CustomCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.secondaryViolet.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${roadmap.totalWeeks} WEEKS • ${roadmap.weeklyHours}H/WEEK',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.secondaryViolet,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Text(
                    '${_completedStages.length} of ${roadmap.stages.length} Completed',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(roadmap.title, style: AppTypography.h2),
              const SizedBox(height: 6),
              Text(roadmap.summary, style: AppTypography.bodySecondary),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Stages List
        ...roadmap.stages.map((stage) {
          final isCompleted = _completedStages.contains(stage.stageNumber);

          return Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: CustomCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: isCompleted
                              ? AppColors.successLight
                              : AppColors.primaryBlue.withOpacity(0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            '${stage.stageNumber}',
                            style: TextStyle(
                              color: isCompleted
                                  ? AppColors.success
                                  : AppColors.primaryBlue,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              stage.title,
                              style: AppTypography.h3.copyWith(fontSize: 16),
                            ),
                            Text(stage.duration, style: AppTypography.caption),
                          ],
                        ),
                      ),
                      Checkbox(
                        value: isCompleted,
                        activeColor: AppColors.success,
                        onChanged: (val) {
                          setState(() {
                            if (val == true) {
                              _completedStages.add(stage.stageNumber);
                            } else {
                              _completedStages.remove(stage.stageNumber);
                            }
                          });
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Divider(),
                  const SizedBox(height: 10),

                  // Topics
                  Text(
                    'Core Topics:',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  ...stage.topics.map(
                    (t) => Padding(
                      padding: const EdgeInsets.only(left: 8, bottom: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '• ',
                            style: TextStyle(color: AppColors.primaryBlue),
                          ),
                          Expanded(
                            child: Text(
                              t,
                              style: AppTypography.bodySecondary.copyWith(
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Practical Exercises
                  Text(
                    'Hands-On Exercise:',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.secondaryViolet,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  ...stage.practicalExercises.map(
                    (ex) => Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '🛠 $ex',
                        style: AppTypography.bodySecondary.copyWith(
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),

        // Tips Card
        if (roadmap.tipsForSuccess.isNotEmpty) ...[
          CustomCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.tips_and_updates_outlined,
                      color: AppColors.warning,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Coach Success Tips',
                      style: AppTypography.h3.copyWith(fontSize: 16),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ...roadmap.tipsForSuccess.map(
                  (tip) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      '💡 $tip',
                      style: AppTypography.bodySecondary.copyWith(fontSize: 13),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ],
    );
  }
}
