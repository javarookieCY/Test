import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../utils/constants.dart';
import '../../utils/exercise_catalog.dart';

/// 從底部滑出的 iOS 滾輪，選某個動作的組數 / 分鐘數。
/// 選項只有 [ExerciseDef.amountOptions]（例如 1–6 組、10–120 分鐘），
/// 所以不可能選出「888 組」這種不合理的數字。按取消回傳 null。
Future<int?> showExerciseAmountPicker(
  BuildContext context,
  ExerciseDef exercise, {
  int? initial,
  bool isUpdate = false,
}) {
  return showCupertinoModalPopup<int>(
    context: context,
    builder: (_) => ExerciseAmountSheet(
      exercise: exercise,
      initial: initial,
      isUpdate: isUpdate,
    ),
  );
}

class ExerciseAmountSheet extends StatefulWidget {
  const ExerciseAmountSheet({
    super.key,
    required this.exercise,
    this.initial,
    this.isUpdate = false,
  });

  final ExerciseDef exercise;
  final int? initial;
  final bool isUpdate;

  @override
  State<ExerciseAmountSheet> createState() => _ExerciseAmountSheetState();
}

class _ExerciseAmountSheetState extends State<ExerciseAmountSheet> {
  late final List<int> _options = widget.exercise.amountOptions;
  late int _index = _options.indexOf(
    widget.exercise.clampAmount(widget.initial ?? widget.exercise.defaultAmount),
  );
  late final _controller = FixedExtentScrollController(initialItem: _index);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.exercise;
    return Material(
      color: ElementColors.cardBg,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
      clipBehavior: Clip.antiAlias,
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 300,
          child: Column(
            children: [
              Row(
                children: [
                  CupertinoButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('取消'),
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        Text(
                          e.name,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                        Text(
                          '可選 ${e.minAmount}–${e.maxAmount} ${e.unit}',
                          style: const TextStyle(color: Colors.white54, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  CupertinoButton(
                    onPressed: () => Navigator.pop(context, _options[_index]),
                    child: Text(widget.isUpdate ? '更新' : '加入',
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
              const Divider(height: 1, color: Colors.white12),
              Expanded(
                child: CupertinoPicker(
                  scrollController: _controller,
                  itemExtent: 38,
                  onSelectedItemChanged: (i) => setState(() => _index = i),
                  children: [
                    for (final v in _options)
                      Center(
                        child: Text('$v ${e.unit}',
                            style: const TextStyle(color: Colors.white, fontSize: 20)),
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
}
