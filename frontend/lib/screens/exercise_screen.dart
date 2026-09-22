import 'package:flutter/material.dart';
import '../utils/chart.dart';
import '../db_helper.dart';
import '../models/exercise_entry.dart';
import '../models/exercise_task.dart';
import '../models/user_profile.dart';
import '../utils/constants.dart';
import '../utils/exercise_data.dart';
import '../widgets/home/week_row.dart';
import 'exercise_task_setup_screen.dart';

class ExerciseScreen extends StatefulWidget {
  const ExerciseScreen({super.key, this.onChanged});

  final VoidCallback? onChanged;

  @override
  State<ExerciseScreen> createState() => _ExerciseScreenState();
}

class _ExerciseScreenState extends State<ExerciseScreen> {
  late final DateTime _today;
  late final List<DateTime> _weekDates;
  late int _selectedIndex;
  List<ExerciseEntry> _entries = [];
  UserProfile? _profile;
  List<double> _weeklyCalories = [];
  List<String> _weeklyLabels = [];

  List<ExerciseTask> _tasks = [];

  int get _totalMinutes => _entries.fold(0, (s, e) => s + e.minutes);
  int get _totalCalories => _entries.fold(0, (s, e) => s + e.calories);

  String _dateKey(DateTime d) => '${d.year}-${d.month}-${d.day}';

  String get _selectedDateStr => _dateKey(_weekDates[_selectedIndex]);

  String get _selectedDateLabel {
    final date = _weekDates[_selectedIndex];
    final diff = date.difference(_today).inDays;
    if (diff == 0) return '今天';
    if (diff == -1) return '昨天';
    if (diff == 1) return '明天';
    return '${date.month}/${date.day}';
  }

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _today = DateTime(now.year, now.month, now.day);
    final monday = _today.subtract(Duration(days: _today.weekday - 1));
    _weekDates = List.generate(7, (i) => monday.add(Duration(days: i)));
    _selectedIndex = _today.weekday - 1;
    _loadForDay();
  }

  void _selectDay(int index) {
    setState(() => _selectedIndex = index);
    _loadForDay();
  }

  /// 切換日期 / 剛進頁面時用：讀完資料後，如果這天還沒設定訓練清單，
  /// 就直接跳出設定頁引導使用者輸入。
  Future<void> _loadForDay() async {
    await _load();
    if (!mounted || _tasks.isNotEmpty) return;
    await _openTaskSetup();
  }

  Future<void> _load() async {
    final entries = await DBHelper.instance.getExercisesByDate(_selectedDateStr);
    final profile = await DBHelper.instance.getUserProfile();
    final tasks = await DBHelper.instance.getExerciseTasksByDate(_selectedDateStr);
    await _loadWeeklyTrend();
    if (!mounted) return;
    setState(() {
      _entries = entries;
      _profile = profile;
      _tasks = tasks;
    });
  }

  Future<void> _openTaskSetup() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ExerciseTaskSetupScreen(
          date: _selectedDateStr,
          dateLabel: _selectedDateLabel,
        ),
      ),
    );
    await _load();
  }

  /// 撈「最近 7 天（含今天）」每天的運動消耗熱量，組成折線圖要的資料。
  /// 用 DBHelper 既有的 getBurnedCaloriesByDate 逐日查詢，沒紀錄的那天會是 0。
  Future<void> _loadWeeklyTrend() async {
    const days = 7;
    final now = DateTime.now();
    final values = <double>[];
    final labels = <String>[];
    for (int i = days - 1; i >= 0; i--) {
      final d = now.subtract(Duration(days: i));
      final kcal = await DBHelper.instance.getBurnedCaloriesByDate(_dateKey(d));
      values.add(kcal.toDouble());
      labels.add('${d.month}/${d.day}');
    }
    if (!mounted) return;
    setState(() {
      _weeklyCalories = values;
      _weeklyLabels = labels;
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

  Future<void> _toggleTaskDone(ExerciseTask task) async {
    if (task.id == null) return;
    await DBHelper.instance.setExerciseTaskDone(task.id!, !task.done);
    await _load();
  }

  Future<void> _deleteTask(int id) async {
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
          Text(_selectedDateLabel, style: kTitleText),
          const SizedBox(height: 12),
          WeekRow(
            today: _today,
            weekDates: _weekDates,
            selectedIndex: _selectedIndex,
            onSelect: _selectDay,
          ),
          const SizedBox(height: 16),
          _summaryCard(),
          const SizedBox(height: 24),
          _taskSectionHeader(),
          if (_tasks.isNotEmpty) ...[
            const SizedBox(height: 12),
            _taskRatioBar(),
          ],
          const SizedBox(height: 8),
          _taskList(),
          const SizedBox(height: 24),
          Text('$_selectedDateLabel紀錄', style: kGreyBoldText),
          const SizedBox(height: 8),
          if (_entries.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text('$_selectedDateLabel還沒有運動紀錄，點右下「記錄運動」新增',
                  style: const TextStyle(color: Colors.white38)),
            )
          else
            ..._entries.map(_entryTile),
          const SizedBox(height: 24),
          const Text('近 7 天消耗熱量', style: kGreyBoldText),
          const SizedBox(height: 8),
          _weeklyTrendChart(),
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

  Widget _taskSectionHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text('$_selectedDateLabel訓練清單', style: kGreyBoldText),
        IconButton(
          icon: const Icon(Icons.playlist_add, color: ElementColors.accent),
          tooltip: '新增動作',
          onPressed: _openTaskSetup,
        ),
      ],
    );
  }

  Widget _taskRatioBar() {
    final strengthCount =
        _tasks.where((t) => t.category == ExerciseTaskCategory.strength).length;
    final cardioCount = _tasks.length - strengthCount;
    final total = _tasks.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: SizedBox(
            height: 8,
            child: Row(
              children: [
                if (strengthCount > 0)
                  Expanded(
                    flex: strengthCount,
                    child: Container(color: ElementColors.accent),
                  ),
                if (cardioCount > 0)
                  Expanded(
                    flex: cardioCount,
                    child: Container(color: ElementColors.cardio),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '重訓 $strengthCount 項・有氧 $cardioCount 項（共 $total 項）',
          style: const TextStyle(color: Colors.white54, fontSize: 12),
        ),
      ],
    );
  }

  Widget _taskList() {
    if (_tasks.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text('還沒設定$_selectedDateLabel的訓練，點右上角「＋」新增動作',
            style: const TextStyle(color: Colors.white38, fontSize: 13)),
      );
    }
    return Column(children: _tasks.map(_taskTile).toList());
  }

  Widget _taskTile(ExerciseTask task) {
    final color =
        task.category == ExerciseTaskCategory.strength ? ElementColors.accent : ElementColors.cardio;
    return Card(
      color: ElementColors.cardBg,
      margin: const EdgeInsets.only(bottom: 6),
      child: CheckboxListTile(
        value: task.done,
        onChanged: (_) => _toggleTaskDone(task),
        activeColor: ElementColors.accent,
        controlAffinity: ListTileControlAffinity.leading,
        title: Text(
          task.name,
          style: TextStyle(
            color: task.done ? Colors.white38 : Colors.white,
            decoration: task.done ? TextDecoration.lineThrough : null,
          ),
        ),
        subtitle: Text(
          task.detailLabel,
          style: const TextStyle(color: Colors.white54, fontSize: 12),
        ),
        secondary: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: color),
              ),
              child: Text(task.category.label,
                  style: TextStyle(color: color, fontSize: 11)),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.white38, size: 20),
              onPressed: task.id == null ? null : () => _deleteTask(task.id!),
            ),
          ],
        ),
      ),
    );
  }

  Widget _weeklyTrendChart() {
    if (_weeklyCalories.every((v) => v == 0)) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: ElementColors.cardBg,
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Text('這幾天還沒有運動紀錄，開始記錄後這裡會畫出趨勢圖',
            style: TextStyle(color: Colors.white38)),
      );
    }
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
      decoration: BoxDecoration(
        color: ElementColors.cardBg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: LineChartSample2(
        dailyValues: _weeklyCalories,
        dayLabels: _weeklyLabels,
      ),
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
              title: Text('記錄運動（$_selectedDateLabel）',
                  style: const TextStyle(color: Colors.white)),
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
                      date: _selectedDateStr,
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
