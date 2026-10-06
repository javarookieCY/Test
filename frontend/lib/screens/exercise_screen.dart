import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../utils/chart.dart';
import '../db_helper.dart';
import '../models/exercise_entry.dart';
import '../models/exercise_task.dart';
import '../models/user_profile.dart';
import '../utils/constants.dart';
import '../utils/exercise_catalog.dart';
import '../utils/exercise_data.dart';
import '../widgets/exercise/category_badge.dart';
import '../widgets/home/week_row.dart';
import 'exercise_task_setup_screen.dart';
import 'weekly_plan_screen.dart';

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
    final index = _selectedIndex;
    await _load();
    // 讀資料期間使用者又切到別天，就不要替舊的那天跳設定頁
    if (!mounted || index != _selectedIndex || _tasks.isNotEmpty) return;
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

  /// 設定頁已經開著：資料還在讀的時候使用者先點了「新增動作」，讀完又自動跳一次會疊出兩層設定頁
  bool _setupOpen = false;

  // 換頁一律用 MaterialPageRoute，不要用 CupertinoPageRoute：
  // 底下的 RootShell 是 MaterialPageRoute，上面疊 CupertinoPageRoute 時兩者轉場不同，
  // 底下那頁會套上 Cupertino 的「被推走」轉場，整頁（GlobalKey）在元件樹裡被搬位置；
  // 再加上 DevicePreview 把整個 App 包在 LayoutBuilder 裡，搬移發生在 layout 階段，
  // 頁面上的 OverlayPortal（Tooltip 等）就會丟出 "mutated in _RenderLayoutBuilder.performLayout"，
  // 返回時元件樹已經壞掉 → '_elements.contains(element)' → 畫面卡死。
  // MaterialPageRoute 會依平台（含 DevicePreview 模擬的 iPhone）自動用 iOS 滑動轉場，外觀不變。
  Future<void> _openTaskSetup() async {
    if (_setupOpen) return;
    _setupOpen = true;
    try {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ExerciseTaskSetupScreen(
            date: _selectedDateStr,
            dateLabel: _selectedDateLabel,
          ),
        ),
      );
    } finally {
      _setupOpen = false;
    }
    await _load();
  }

  /// 打開「本週計畫」；在那頁按下套用會回傳 true，這邊重新讀清單
  Future<void> _openWeeklyPlan() async {
    final profile = _profile;
    if (profile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('請先到「日記」頁填寫個人資料，才能排出計畫')),
      );
      return;
    }
    final applied = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => WeeklyPlanScreen(profile: profile)),
    );
    await _load();
    if (applied == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已把本週計畫套用到訓練清單')),
      );
    }
  }

  /// 撈「最近 7 天（含今天）」每天的運動消耗熱量，組成折線圖要的資料。
  /// 每天 = 運動紀錄的熱量 + 訓練清單裡「已打勾」動作的估計熱量（MET × 體重 × 時間），
  /// 沒紀錄的那天會是 0。
  Future<void> _loadWeeklyTrend() async {
    const days = 7;
    final now = DateTime.now();
    final weightKg = (await DBHelper.instance.getUserProfile())?.weightKg;
    final values = <double>[];
    final labels = <String>[];
    for (int i = days - 1; i >= 0; i--) {
      final d = DateTime(now.year, now.month, now.day - i);
      final recorded = await DBHelper.instance.getBurnedCaloriesByDate(_dateKey(d));
      final tasks = await DBHelper.instance.getExerciseTasksByDate(_dateKey(d));
      final fromTasks = tasks
          .where((t) => t.done)
          .fold(0, (sum, t) => sum + estimateTaskKcal(t, weightKg: weightKg));
      final kcal = recorded + fromTasks;
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
        actions: [
          CupertinoButton(
            onPressed: _openWeeklyPlan,
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(CupertinoIcons.calendar, size: 20, color: ElementColors.lightUi),
                SizedBox(width: 4),
                Text('本週計畫', style: TextStyle(color: ElementColors.lightUi)),
              ],
            ),
          ),
        ],
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
          const Text('近 7 天消耗熱量（運動紀錄＋已打勾的訓練清單）', style: kGreyBoldText),
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
    final counts = {
      for (final c in ExerciseTaskCategory.values)
        c: _tasks.where((t) => t.category == c).length,
    };
    final present = counts.entries.where((e) => e.value > 0).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: SizedBox(
            height: 8,
            child: Row(
              children: [
                for (int i = 0; i < present.length; i++) ...[
                  if (i > 0) const SizedBox(width: 2), // 段與段之間留 2px 縫
                  Expanded(
                    flex: present[i].value,
                    child: Container(color: categoryColor(present[i].key)),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${present.map((e) => '${e.key.label} ${e.value} 項').join('・')}（共 ${_tasks.length} 項）',
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
            CategoryBadge(task.category),
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
    String? minutesError;

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
                      decoration: InputDecoration(
                        labelText: '時長（分鐘，1–$kMaxExerciseMinutes）',
                        labelStyle: const TextStyle(color: Colors.white54),
                        errorText: minutesError,
                      ),
                      onChanged: (_) {
                        minutesError = null;
                        recalc(setDialogState);
                      },
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
                    if (mins == null || mins <= 0 || mins > kMaxExerciseMinutes) {
                      setDialogState(
                          () => minutesError = '請輸入 1–$kMaxExerciseMinutes 分鐘');
                      return;
                    }
                    if (kcal == null || kcal < 0) return;
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
