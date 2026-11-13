import 'package:flutter/material.dart';
import 'package:forui/forui.dart';

import '../../../theme/signage_theme.dart';
import '../models/placement_models.dart';

/// 10-column square Answer Navigator rendered inside a zero-radius [FSheet].
class AnswerNavigatorSheet extends StatefulWidget {
  const AnswerNavigatorSheet({
    super.key,
    required this.questions,
    required this.currentIndex,
    required this.onSelectIndex,
  });

  final List<PlacementQuestion> questions;
  final int currentIndex;
  final ValueChanged<int> onSelectIndex;

  @override
  State<AnswerNavigatorSheet> createState() => _AnswerNavigatorSheetState();
}

class _AnswerNavigatorSheetState extends State<AnswerNavigatorSheet> {
  bool _onlyFlagged = false;

  @override
  Widget build(BuildContext context) {
    final entries = <({int index, PlacementQuestion question})>[];
    for (var i = 0; i < widget.questions.length; i++) {
      final q = widget.questions[i];
      if (!_onlyFlagged || q.isFlagged) {
        entries.add((index: i, question: q));
      }
    }

    return Container(
      key: const Key('answer-navigator-sheet'),
      decoration: const BoxDecoration(
        color: SignageColors.paper,
        border: Border(
          top: BorderSide(color: SignageColors.ink, width: 2),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'ANSWER NAVIGATOR',
                      style: SignageTypography.title().copyWith(fontSize: 16),
                    ),
                  ),
                  FTappable(
                    onPress: () => Navigator.of(context).pop(),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: SignageColors.paper,
                        border: Border.all(color: SignageColors.ink, width: 2),
                      ),
                      child: Text(
                        'CLOSE',
                        style: SignageTypography.label(fontSize: 11),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              FSwitch(
                key: const Key('only-flagged-toggle'),
                label: const Text('Only Flagged'),
                value: _onlyFlagged,
                onChange: (value) => setState(() => _onlyFlagged = value),
              ),
              const SizedBox(height: 12),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 280),
                child: GridView.builder(
                  key: const Key('answer-navigator-grid'),
                  shrinkWrap: true,
                  itemCount: entries.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 10,
                    crossAxisSpacing: 4,
                    mainAxisSpacing: 4,
                    childAspectRatio: 1,
                  ),
                  itemBuilder: (context, gridIdx) {
                    final entry = entries[gridIdx];
                    final idx = entry.index;
                    final q = entry.question;
                    final isCurrent = idx == widget.currentIndex;

                    final Color bgColor;
                    final Color textColor;
                    if (q.isFlagged) {
                      bgColor = SignageColors.signGold;
                      textColor = SignageColors.ink;
                    } else if (q.isAnswered) {
                      bgColor = SignageColors.ink;
                      textColor = SignageColors.paper;
                    } else {
                      bgColor = SignageColors.track;
                      textColor = SignageColors.inkMuted;
                    }

                    return FTappable(
                      onPress: () {
                        Navigator.of(context).pop();
                        widget.onSelectIndex(idx);
                      },
                      child: Container(
                        key: Key('nav-cell-$idx'),
                        decoration: BoxDecoration(
                          color: bgColor,
                          border: Border.all(
                            color: isCurrent
                                ? SignageColors.signBlue
                                : SignageColors.ink,
                            width: isCurrent ? 3 : 1,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            '${idx + 1}',
                            style: SignageTypography.data(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: textColor,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
