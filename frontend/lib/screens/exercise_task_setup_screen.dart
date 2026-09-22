import 'package:flutter/material.dart';
import '../db_helper.dart';
import '../models/exercise_task.dart';
import '../utils/constants.dart';

/// 設定某一天的訓練清單：選重訓或有氧，輸入動作＋組數（重訓）或
/// 動作＋分鐘數（有氧），一筆筆加進清單；完成後回到運動頁打勾。
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
  final _nameCtrl = TextEditingController();
  final _countCtrl = TextEditingController();
  List<ExerciseTask> _tasks = [];

  bool get _isStrength => _category == ExerciseTaskCategory.strength;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _countCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final tasks = await DBHelper.instance.getExerciseTasksByDate(widget.date);
    if (!mounted) return;
    setState(() => _tasks = tasks);
  }

  Future<void> _addTask() async {
    final name = _nameCtrl.text.trim();
    final count = int.tryParse(_countCtrl.text.trim());
    if (name.isEmpty || count == null || count <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_isStrength ? '請輸入動作名稱與組數' : '請輸入動作名稱與分鐘數')),
      );
      return;
    }
    await DBHelper.instance.insertExerciseTask(ExerciseTask(
      date: widget.date,
      category: _category,
      name: name,
      sets: _isStrength ? count : null,
      minutes: _isStrength ? null : count,
    ));
    _nameCtrl.clear();
    _countCtrl.clear();
    await _load();
  }

  Future<void> _removeTask(int id) async {
    await DBHelper.instance.deleteExerciseTask(id);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ElementColors.background,
      appBar: AppBar(
        backgroundColor: ElementColors.background,
        foregroundColor: Colors.white,
        title: Text('設定${widget.dateLabel}的訓練'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: ElementColors.accent,
        foregroundColor: Colors.white,
        onPressed: () => Navigator.pop(context),
        icon: const Icon(Icons.check),
        label: const Text('完成，回到運動頁'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 96),
        children: [
          const Text('今天要練什麼？', style: TextStyle(color: Colors.white70, fontSize: 14)),
          const SizedBox(height: 8),
          SegmentedButton<ExerciseTaskCategory>(
            style: segmentedStyleOnDark(),
            segments: const [
              ButtonSegment(value: ExerciseTaskCategory.strength, label: Text('重訓')),
              ButtonSegment(value: ExerciseTaskCategory.cardio, label: Text('有氧')),
            ],
            selected: {_category},
            onSelectionChanged: (s) => setState(() => _category = s.first),
          ),
          const SizedBox(height: 20),
          _field(
            controller: _nameCtrl,
            label: '動作',
            hint: _isStrength ? '例如：深蹲' : '例如：跑步',
          ),
          const SizedBox(height: 12),
          _field(
            controller: _countCtrl,
            label: _isStrength ? '組數' : '分鐘數',
            hint: _isStrength ? '例如：3' : '例如：20',
            keyboardType: TextInputType.number,
            onSubmitted: (_) => _addTask(),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: ElementColors.accent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: _addTask,
              icon: const Icon(Icons.add),
              label: const Text('加入清單'),
            ),
          ),
          const SizedBox(height: 28),
          Text('已加入（${_tasks.length}）', style: kGreyBoldText),
          const SizedBox(height: 8),
          if (_tasks.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text('還沒加入動作，填好上面的表單後點「加入清單」',
                  style: TextStyle(color: Colors.white38)),
            )
          else
            ..._tasks.map(_taskRow),
        ],
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required String hint,
    TextInputType? keyboardType,
    ValueChanged<String>? onSubmitted,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.white),
      onSubmitted: onSubmitted,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: const TextStyle(color: Colors.white54),
        hintStyle: const TextStyle(color: Colors.white24),
        filled: true,
        fillColor: ElementColors.cardBg,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _taskRow(ExerciseTask task) {
    final color =
        task.category == ExerciseTaskCategory.strength ? ElementColors.accent : ElementColors.cardio;
    return Card(
      color: ElementColors.cardBg,
      margin: const EdgeInsets.only(bottom: 6),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color),
          ),
          child: Text(task.category.label, style: TextStyle(color: color, fontSize: 11)),
        ),
        title: Text(task.name, style: const TextStyle(color: Colors.white)),
        subtitle: Text(task.detailLabel,
            style: const TextStyle(color: Colors.white54, fontSize: 12)),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline, color: Colors.white38),
          onPressed: task.id == null ? null : () => _removeTask(task.id!),
        ),
      ),
    );
  }
}
