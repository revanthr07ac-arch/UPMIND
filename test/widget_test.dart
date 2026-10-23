import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:upmind/core/widgets/custom_button.dart';
import 'package:upmind/core/widgets/empty_state.dart';
import 'package:upmind/core/widgets/skill_chip.dart';
import 'package:upmind/core/widgets/upmind_logo.dart';

void main() {
  group('UPMIND Core Widgets Tests', () {
    testWidgets('UpmindLogo renders brand title and tagline', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: UpmindLogo(size: 48),
          ),
        ),
      );

      expect(find.text('UPMIND'), findsOneWidget);
      expect(
        find.text('Showcase Skills. Share Knowledge. Grow Together.'),
        findsOneWidget,
      );
    });

    testWidgets('CustomButton renders text and triggers callback', (tester) async {
      bool tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CustomButton(
              text: 'Get Started',
              onPressed: () => tapped = true,
            ),
          ),
        ),
      );

      expect(find.text('Get Started'), findsOneWidget);
      await tester.tap(find.text('Get Started'));
      expect(tapped, isTrue);
    });

    testWidgets('CustomButton shows loading indicator when isLoading is true', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CustomButton(
              text: 'Loading Action',
              isLoading: true,
            ),
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Loading Action'), findsNothing);
    });

    testWidgets('SkillChip displays label and intent icons', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SkillChip(
              label: 'Flutter & Dart',
              intent: SkillIntent.teach,
              level: 'advanced',
            ),
          ),
        ),
      );

      expect(find.text('Flutter & Dart'), findsOneWidget);
      expect(find.text('ADVANCED'), findsOneWidget);
      expect(find.byIcon(Icons.school_outlined), findsOneWidget);
    });

    testWidgets('EmptyState displays icon, title and description', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: EmptyState(
              icon: Icons.search_off,
              title: 'No Results Found',
              message: 'Try a different search keyword.',
            ),
          ),
        ),
      );

      expect(find.text('No Results Found'), findsOneWidget);
      expect(find.text('Try a different search keyword.'), findsOneWidget);
      expect(find.byIcon(Icons.search_off), findsOneWidget);
    });
  });
}
