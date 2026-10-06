import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../utils/constants.dart';
import '../../utils/exercise_catalog.dart';
import '../../utils/exercise_guides.dart';
import 'category_badge.dart';

/// 從底部滑出的動作說明：練到哪裡、步驟、注意事項。
Future<void> showExerciseGuide(BuildContext context, ExerciseDef exercise) {
  return showCupertinoModalPopup<void>(
    context: context,
    builder: (_) => ExerciseGuideSheet(exercise: exercise),
  );
}

class ExerciseGuideSheet extends StatelessWidget {
  const ExerciseGuideSheet({super.key, required this.exercise});
  final ExerciseDef exercise;

  @override
  Widget build(BuildContext context) {
    final e = exercise;
    final guide = kExerciseGuides[e.name];
    final maxHeight = MediaQuery.sizeOf(context).height * 0.75;
    return Material(
      color: ElementColors.cardBg,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
      clipBehavior: Clip.antiAlias,
      child: SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 8, 8),
                child: Row(
                  children: [
                    CategoryIconTile(e.category),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(e.name,
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                          Text(e.subtitle, style: const TextStyle(color: Colors.white70)),
                        ],
                      ),
                    ),
                    CupertinoButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('關閉'),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: Colors.white12),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                  children: guide == null
                      ? const [Text('這個動作還沒有說明', style: TextStyle(color: Colors.white))]
                      : [
                          _heading('訓練部位'),
                          Text(guide.muscles,
                              style: const TextStyle(color: Colors.white, height: 1.5)),
                          const SizedBox(height: 16),
                          _heading('動作步驟'),
                          for (int i = 0; i < guide.steps.length; i++)
                            _line('${i + 1}', guide.steps[i]),
                          const SizedBox(height: 16),
                          _heading('注意事項'),
                          for (final tip in guide.tips) _line('•', tip),
                          const SizedBox(height: 16),
                          _heading('建議份量'),
                          Text(
                            '一次 ${e.minAmount}–${e.maxAmount} ${e.unit}',
                            style: const TextStyle(color: Colors.white, height: 1.5),
                          ),
                        ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _heading(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text,
            style: const TextStyle(
                color: ElementColors.lightUi, fontWeight: FontWeight.bold, fontSize: 15)),
      );

  Widget _line(String marker, String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 22,
              child: Text(marker,
                  style: const TextStyle(color: ElementColors.lightUi, height: 1.5)),
            ),
            Expanded(
              child: Text(text, style: const TextStyle(color: Colors.white, height: 1.5)),
            ),
          ],
        ),
      );
}
