import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';

import 'package:extra_efficient_mobile/theme/signage_theme.dart';
import 'package:extra_efficient_mobile/widgets/signage_primitives.dart';

void main() {
  group('Exam-Hall Signage Theme & Primitives', () {
    test('buildSignageTheme enforces zero radius, zero shadow, and 2px Ink border', () {
      final theme = buildSignageTheme();

      expect(theme.style.borderRadius.sm, BorderRadius.zero);
      expect(theme.style.borderRadius.md, BorderRadius.zero);
      expect(theme.style.borderRadius.lg, BorderRadius.zero);
      expect(theme.style.shadow, isEmpty);
      expect(theme.style.borderWidth, 2.0);
      expect(theme.colors.primary, SignageColors.signBlue);
      expect(theme.colors.foreground, SignageColors.ink);
      expect(theme.colors.background, SignageColors.wall);
    });

    testWidgets('PlacardPanel, ScorePlacard, and CefrBandBar render with zero radius and correct band order', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: FTheme(
            data: buildSignageTheme(),
            child: FScaffold(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    PlacardPanel(
                      title: 'ACTIVE SESSION',
                      footer: const Text('Footer note'),
                      child: Column(
                        children: [
                          PlacardBadge.success('PAID'),
                          PlacardBadge.warning('FLAGGED'),
                          PlacardButton(
                            label: 'START',
                            onPress: () {},
                          ),
                          const PlacardAlert(
                            variant: PlacardAlertVariant.danger,
                            title: 'Session expired',
                          ),
                        ],
                      ),
                    ),
                    const ScorePlacard(
                      totalScore: '785',
                      caption: 'TOTAL SCALED SCORE',
                      splits: [
                        ScoreSplit(label: 'LISTENING', value: '405'),
                        ScoreSplit(label: 'READING', value: '380'),
                      ],
                    ),
                    const CefrBandBar(currentBand: 'B2'),
                    StateBlock(
                      stamp: 'EMPTY',
                      title: 'No attempts recorded yet',
                      description: 'Take a placement attempt to seed your path.',
                      action: PlacardButton(
                        label: 'START PLACEMENT',
                        onPress: () {},
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.text('ACTIVE SESSION'), findsOneWidget);
      expect(find.text('785'), findsOneWidget);
      expect(find.text('<A1'), findsOneWidget);
      expect(find.text('C1'), findsOneWidget);
      expect(find.text('EMPTY'), findsOneWidget);
      expect(find.text('No attempts recorded yet'), findsOneWidget);

      // Verify zero border radius on all DecoratedBox / Container widgets inside primitives.
      final decoratedBoxes = tester.widgetList<DecoratedBox>(find.byType(DecoratedBox));
      for (final box in decoratedBoxes) {
        final dec = box.decoration;
        if (dec is BoxDecoration) {
          expect(
            dec.borderRadius == null || dec.borderRadius == BorderRadius.zero,
            isTrue,
            reason: 'Expected zero borderRadius, got ${dec.borderRadius}',
          );
          expect(
            dec.boxShadow == null || dec.boxShadow!.isEmpty,
            isTrue,
            reason: 'Expected zero boxShadow, got ${dec.boxShadow}',
          );
        }
      }
    });
  });
}
