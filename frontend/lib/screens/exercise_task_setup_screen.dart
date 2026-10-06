import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../db_helper.dart';
import '../models/exercise_task.dart';
import '../utils/constants.dart';
import '../utils/exercise_catalog.dart';
import '../widgets/common/app_list_section.dart';
import '../widgets/exercise/amount_picker.dart';
import '../widgets/exercise/category_badge.dart';
import '../widgets/exercise/exercise_guide_sheet.dart';

/// 設定某一天的訓練清單（iOS Cupertino 風格）。
/// 動作只能從動作庫挑（不開放自己取名），組數 / 分鐘數用滾輪選、只能選在該動作的合理範圍內。
/// 同一個動作在同一天只會有一筆：再點一次是修改份量，不會重複加入（避免疊出 888 組）。
/// 預設只列出使用者有器材可以做的動作（器材在個人資料設定），可以切換成顯示全部。
class ExerciseTaskSetupScreen extends StatefulWidget {
  const ExerciseTaskSetupScreen({
    super.key,
    required this.date,
    required this.dateLabel,
  });

  final String date; // yyyy-M-d，存進 DB 用
  final String dateLabel; // 顯示用，例如「今天」「9/23」

  @override
  State<ExerciseTaskSetupScreen> createState() => _ExerciseTaskSetupScreenState();
}

class _ExerciseTaskSetupScreenState extends State<ExerciseTaskSetupScreen> {
  ExerciseTaskCategory _category = ExerciseTaskCategory.strength;
  String _query = '';
  List<ExerciseTask> _tasks = [];
  Set<Equipment>? _equipment; // null = 還沒填個人資料，不篩選
  bool _onlyMyEquipment = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final tasks = await DBHelper.instance.getExerciseTasksByDate(widget.date);
    final profile = await DBHelper.instance.getUserProfile();
    if (!mounted) return;
    setState(() {
      _tasks = tasks;
      _equipment = profile?.equipment;
    });
  }

  ExerciseTask? _taskFor(ExerciseDef e) =>
      _tasks.where((t) => t.name == e.name).firstOrNull;

  /// 挑好動作 → 滾輪選份量 → 新增；這天已經有這個動作就改成更新份量
  Future<void> _pick(ExerciseDef e) async {
    final existing = _taskFor(e);
    final amount = await showExerciseAmountPicker(
      context,
      e,
      initial: existing?.sets ?? existing?.minutes,
      isUpdate: existing != null,
    );
    if (amount == null || !e.isValidAmount(amount)) return;

    final sets = e.category.usesSets ? amount : null;
    final minutes = e.category.usesSets ? null : amount;
    if (existing?.id != null) {
      await DBHelper.instance
          .updateExerciseTaskAmount(existing!.id!, sets: sets, minutes: minutes);
    } else {
      await DBHelper.instance.insertExerciseTask(ExerciseTask(
        date: widget.date,
        category: e.category,
        name: e.name,
        sets: sets,
        minutes: minutes,
      ));
    }
    await _load();
  }

  Future<void> _removeTask(int id) async {
    await DBHelper.instance.deleteExerciseTask(id);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: ElementColors.background,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: ElementColors.background,
        border: null,
        previousPageTitle: '運動',
        middle: Text('設定${widget.dateLabel}的訓練'),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => Navigator.pop(context),
          child: const Text('完成', style: TextStyle(fontWeight: FontWeight.w600)),
        ),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              _addedSection(),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: CupertinoSlidingSegmentedControl<ExerciseTaskCategory>(
                  groupValue: _category,
                  thumbColor: ElementColors.accent,
                  backgroundColor: ElementColors.cardBg,
                  children: {
                    for (final c in ExerciseTaskCategory.values)
                      c: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Text(c.label, style: const TextStyle(color: Colors.white)),
                      ),
                  },
                  onValueChanged: (c) {
                    if (c != null) setState(() => _category = c);
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                child: CupertinoSearchTextField(
                  placeholder: '搜尋動作，例如：深蹲、Squat、胸',
                  style: const TextStyle(color: Colors.white),
                  backgroundColor: ElementColors.cardBg,
                  onChanged: (v) => setState(() => _query = v),
                ),
              ),
              if (_equipment != null) _equipmentFilter(),
              ..._catalogSections(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _addedSection() {
    return AppListSection(
      header: Text('${widget.dateLabel}已加入（${_tasks.length}）'),
      footer: const Text('點動作可以修改組數 / 分鐘數'),
      children: _tasks.isEmpty
          ? [
              const CupertinoListTile(
                title: Text('還沒加入動作，從下方動作庫挑選',
                    style: TextStyle(color: Colors.white38, fontSize: 15)),
              ),
            ]
          : _tasks.map(_addedTile).toList(),
    );
  }

  Widget _addedTile(ExerciseTask task) {
    final def = findExercise(task.name);
    return CupertinoListTile(
      leading: CategoryIconTile(task.category),
      title: Text(task.name),
      additionalInfo: Text(task.detailLabel),
      onTap: def == null ? null : () => _pick(def),
      trailing: CupertinoButton(
        padding: EdgeInsets.zero,
        minimumSize: const Size(32, 32),
        onPressed: task.id == null ? null : () => _removeTask(task.id!),
        child: const Icon(CupertinoIcons.minus_circle_fill,
            color: CupertinoColors.systemRed, size: 22),
      ),
    );
  }

  Widget _equipmentFilter() {
    final names = [
      for (final e in Equipment.values)
        if (_equipment!.contains(e)) e.label
    ].join('、');
    return AppListSection(
      hasLeading: false,
      children: [
        CupertinoListTile(
          title: const Text('只顯示我有器材的動作'),
          subtitle: Text('$names（在個人資料修改）'),
          trailing: CupertinoSwitch(
            value: _onlyMyEquipment,
            activeTrackColor: ElementColors.accent,
            onChanged: (v) => setState(() => _onlyMyEquipment = v),
          ),
        ),
      ],
    );
  }

  List<Widget> _catalogSections() {
    final results = searchCatalog(_query, _category,
        equipment: _onlyMyEquipment ? _equipment : null);
    if (results.isEmpty) {
      return [
        AppListSection(
          hasLeading: false,
          footer: Text(_onlyMyEquipment && _equipment != null
              ? '目前只顯示你有器材的動作，可以關掉上面的開關看全部'
              : '動作庫只收錄常見的標準動作，換個關鍵字試試'),
          children: [
            CupertinoListTile(
              title: Text('找不到「${_query.trim()}」',
                  style: const TextStyle(color: Colors.white54, fontSize: 15)),
            ),
          ],
        ),
      ];
    }
    if (_category != ExerciseTaskCategory.strength) {
      return [
        AppListSection(
          header: Text('${_category.label}動作'),
          children: results.map(_catalogTile).toList(),
        ),
      ];
    }
    // 重訓依部位分組
    return [
      for (final part in BodyPart.values)
        if (results.any((e) => e.bodyPart == part))
          AppListSection(
            header: Text(part.label),
            children:
                results.where((e) => e.bodyPart == part).map(_catalogTile).toList(),
          ),
    ];
  }

  Widget _catalogTile(ExerciseDef e) {
    final added = _taskFor(e);
    return CupertinoListTile(
      leading: CategoryIconTile(e.category),
      title: Text(e.name),
      subtitle: Text(e.subtitle),
      additionalInfo: added == null ? null : Text(added.detailLabel),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CupertinoButton(
            padding: EdgeInsets.zero,
            minimumSize: const Size(36, 36),
            onPressed: () => showExerciseGuide(context, e),
            child: const Icon(CupertinoIcons.info_circle, color: Colors.white54, size: 22),
          ),
          const SizedBox(width: 4),
          Icon(
            added == null ? CupertinoIcons.add_circled : CupertinoIcons.checkmark_circle_fill,
            color: categoryColor(e.category),
            size: 22,
          ),
        ],
      ),
      onTap: () => _pick(e),
    );
  }
}
