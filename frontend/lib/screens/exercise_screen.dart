import 'package:flutter/material.dart';

import '../db_helper.dart';
import '../models/exercise_entry.dart';
import '../models/user_profile.dart';
import '../utils/constants.dart';
import '../utils/exercise_data.dart';

/// 「運動」頁（主畫面往左滑）。
/// 記錄運動類型 / 時長 / 消耗熱量，並提供內建訓練計畫。
/// [onChanged] 在新增或刪除紀錄後呼叫，讓首頁重新把「消耗熱量」加回剩餘熱量。
class ExerciseScreen extends StatefulWidget {
  const ExerciseScreen({super.key, this.onChanged});

  final VoidCallback? onChanged;

  @override
  State<ExerciseScreen> createState() => _ExerciseScreenState();
}

class _ExerciseScreenState extends State<ExerciseScreen> {
  late final String _todayStr;
  List<ExerciseEntry> _entries = [];
  UserProfile? _profile;

  int get _totalMinutes => _entries.fold(0, (s, e) => s + e.minutes);
  int get _totalCalories => _entries.fold(0, (s, e) => s + e.calories);

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _todayStr = '${now.year}-${now.month}-${now.day}';
    _load();
  }

  Future<void> _load() async {
    final entries = await DBHelper.instance.getExercisesByDate(_todayStr);
    final profile = await DBHelper.instance.getUserProfile();
    if (!mounted) return;
    setState(() {
      _entries = entries;
      _profile = profile;
    });
  }

  Future<void> _addEntry(ExerciseEntry entry) async {
    await DBHelper.instance.insertExercise(entry);
    await _load();
    widget.onChanged?.call();
  }

  Future<void> _deleteEntry(int id) async {
    await DBHelper.instance.deleteExercise(id);
    await _load();
    widget.onChanged?.call();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ElementColors.background,
      appBar: AppBar(
        backgroundColor: ElementColors.background,
        foregroundColor: Colors.white,
        title: const Text('運動'),
        automaticallyImplyLeading: false,
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: ElementColors.accent,
        foregroundColor: Colors.white,
        onPressed: _showRecordDialog,
        icon: const Icon(Icons.add),
        label: const Text('記錄運動'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(15, 15, 15, 96),
        children: [
          _summaryCard(),
          const SizedBox(height: 16),
          const Text('今日紀錄', style: kGreyBoldText),
          const SizedBox(height: 8),
          if (_entries.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text('今天還沒有運動紀錄，點右下「記錄運動」新增',
                  style: TextStyle(color: Colors.white38)),
            )
          else
            ..._entries.map(_entryTile),
          const SizedBox(height: 24),
          const Text('訓練計畫', style: kGreyBoldText),
          const SizedBox(height: 8),
          ...kWorkoutPlans.map(_planCard),
        ],
      ),
    );
  }

  Widget _summaryCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ElementColors.cardBg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _stat('$_totalMinutes', '分鐘'),
          _stat('$_totalCalories', 'kcal 消耗'),
          _stat('${_entries.length}', '筆紀錄'),
        ],
      ),
    );
  }

  Widget _stat(String value, String label) {
    return Column(
      children: [
        Text(value,
            style: const TextStyle(
                color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12)),
      ],
    );
  }

  Widget _entryTile(ExerciseEntry e) {
    return Card(
      color: ElementColors.cardBg,
      margin: const EdgeInsets.only(bottom: 6),
      child: ListTile(
        title: Text(e.name, style: const TextStyle(color: Colors.white)),
        subtitle: Text('${e.minutes} 分鐘 ・ ${e.calories} kcal',
            style: const TextStyle(color: Colors.white54, fontSize: 12)),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline, color: Colors.white38),
          onPressed: e.id == null ? null : () => _deleteEntry(e.id!),
        ),
      ),
    );
  }

  Widget _planCard(WorkoutPlan plan) {
    return Card(
      color: ElementColors.cardBg,
      margin: const EdgeInsets.only(bottom: 8),
      child: ExpansionTile(
        collapsedIconColor: Colors.white54,
        iconColor: ElementColors.accent,
        title: Text(plan.title, style: const TextStyle(color: Colors.white)),
        subtitle: Text(plan.subtitle,
            style: const TextStyle(color: Colors.white54, fontSize: 12)),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        children: plan.items
            .map(
              (line) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('・', style: TextStyle(color: Colors.white54)),
                    Expanded(
                      child: Text(line,
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 13, height: 1.4)),
                    ),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  void _showRecordDialog() {
    ExercisePreset selected = kExercisePresets.first;
    ExerciseIntensity intensity = selected.defaultIntensity;
    final minutesCtrl = TextEditingController(text: '30');
    final kcalCtrl = TextEditingController();
    bool kcalEditedManually = false;

    void recalc(StateSetter setDialogState) {
      if (kcalEditedManually) {
        setDialogState(() {});
        return;
      }
      final mins = int.tryParse(minutesCtrl.text.trim()) ?? 0;
      final est = estimateExerciseKcal(
        met: intensity.met,
        minutes: mins,
        weightKg: _profile?.weightKg,
      );
      kcalCtrl.text = est.toString();
      setDialogState(() {});
    }

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            // 首次開啟先算一次估計值
            if (kcalCtrl.text.isEmpty) recalc(setDialogState);

            return AlertDialog(
              backgroundColor: ElementColors.cardBg,
              title: const Text('記錄運動', style: TextStyle(color: Colors.white)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('類型', style: TextStyle(color: Colors.white54, fontSize: 12)),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: kExercisePresets.map((p) {
                        final on = p.name == selected.name;
                        return ChoiceChip(
                          label: Text(p.name),
                          selected: on,
                          labelStyle: TextStyle(
                              color: on ? Colors.white : ElementColors.lightUi),
                          backgroundColor: ElementColors.accentDim,
                          selectedColor: ElementColors.accent,
                          onSelected: (_) {
                            selected = p;
                            intensity = p.defaultIntensity; // 換運動就重設強度
                            recalc(setDialogState);
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 12),
                    const Text('強度 / 配速',
                        style: TextStyle(color: Colors.white54, fontSize: 12)),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: selected.intensities.map((it) {
                        final on = it.label == intensity.label;
                        return ChoiceChip(
                          label: Text(it.label),
                          selected: on,
                          labelStyle: TextStyle(
                              color: on ? Colors.white : ElementColors.lightUi,
                              fontSize: 12),
                          backgroundColor: ElementColors.accentDim,
                          selectedColor: ElementColors.accent,
                          onSelected: (_) {
                            intensity = it;
                            recalc(setDialogState);
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: minutesCtrl,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: '時長（分鐘）',
                        labelStyle: TextStyle(color: Colors.white54),
                      ),
                      onChanged: (_) => recalc(setDialogState),
                    ),
                    TextField(
                      controller: kcalCtrl,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: '消耗熱量 (kcal)',
                        labelStyle: const TextStyle(color: Colors.white54),
                        helperText: kcalEditedManually
                            ? '已手動修改，不再自動估算'
                            : '依 強度(MET ${intensity.met}) × 體重 × 時間估算，可自行修改',
                        helperStyle:
                            const TextStyle(color: Colors.white38, fontSize: 11),
                      ),
                      onChanged: (_) => kcalEditedManually = true,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('取消'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ElementColors.accent,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () {
                    final mins = int.tryParse(minutesCtrl.text.trim());
                    final kcal = int.tryParse(kcalCtrl.text.trim());
                    if (mins == null || mins <= 0 || kcal == null || kcal < 0) return;
                    Navigator.pop(dialogContext);
                    _addEntry(ExerciseEntry(
                      date: _todayStr,
                      // 把強度一起記進名稱，之後歷史看得出來（exercises 表沒有獨立欄位）
                      name: '${selected.name}（${intensity.label}）',
                      minutes: mins,
                      calories: kcal,
                    ));
                  },
                  child: const Text('儲存'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
