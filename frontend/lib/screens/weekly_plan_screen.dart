import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../db_helper.dart';
import '../models/user_profile.dart';
import '../utils/constants.dart';
import '../utils/nutrition_math.dart';
import '../utils/workout_planner.dart';
import '../widgets/common/app_list_section.dart';
import '../widgets/exercise/category_badge.dart';
import '../widgets/exercise/exercise_guide_sheet.dart';

/// 「本週計畫」頁（iOS Cupertino 風格）：依個人資料自動排出的一週訓練。
/// 版面參考常見健身 App：最上面說明依身體狀況做了哪些調整 → 一週總覽 → 每天的動作清單，
/// 最下面一鍵套用到本週的訓練清單。套用成功會 pop(true)。
class WeeklyPlanScreen extends StatefulWidget {
  const WeeklyPlanScreen({super.key, required this.profile, this.now});

  final UserProfile profile;

  /// 測試用；預設是 DateTime.now()
  final DateTime? now;

  @override
  State<WeeklyPlanScreen> createState() => _WeeklyPlanScreenState();
}

class _WeeklyPlanScreenState extends State<WeeklyPlanScreen> {
  static const _weekdays = ['一', '二', '三', '四', '五', '六', '日'];

  bool _applying = false;

  late final DateTime _now = widget.now ?? DateTime.now();
  late final DateTime _today = DateTime(_now.year, _now.month, _now.day);
  late Set<int> _weekdaysChosen = {...widget.profile.workoutWeekdays};
  late WeeklyPlan _plan = _buildPlan();

  WeeklyPlan _buildPlan() => buildWeeklyPlan(
        goal: widget.profile.goal,
        workoutWeekdays: _weekdaysChosen,
        age: widget.profile.age,
        weightKg: widget.profile.weightKg,
        heightCm: widget.profile.heightCm,
        equipment: widget.profile.equipment,
      );

  DateTime _dateOf(int i) =>
      DateTime(_today.year, _today.month, _today.day - (_today.weekday - 1) + i);

  /// 點一週總覽的圓圈：切換那天要不要運動，計畫立刻重排並存進個人資料
  Future<void> _toggleDay(int weekday) async {
    final next = {..._weekdaysChosen};
    if (next.contains(weekday)) {
      if (next.length == 1) return _notice('至少要選一天運動');
      next.remove(weekday);
    } else {
      if (next.length >= kMaxWorkoutDays) return _notice('一週最多 $kMaxWorkoutDays 天，至少留一天休息');
      next.add(weekday);
    }
    setState(() {
      _weekdaysChosen = next;
      _plan = _buildPlan();
    });
    await DBHelper.instance.updateWorkoutWeekdays(next);
  }

  Future<void> _notice(String text) => showCupertinoDialog<void>(
        context: context,
        builder: (ctx) => CupertinoAlertDialog(
          content: Text(text),
          actions: [
            CupertinoDialogAction(onPressed: () => Navigator.pop(ctx), child: const Text('好')),
          ],
        ),
      );

  Future<void> _confirmApply() async {
    final ok = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('套用本週計畫？'),
        content: const Text('今天到週日、還沒打勾的訓練清單會換成這份計畫；已經有打勾的日子不會動。'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('套用'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _applying = true);
    try {
      await DBHelper.instance.applyWeeklyPlan(planToTasks(_plan, _now));
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      debugPrint('套用本週計畫失敗: $e');
      if (!mounted) return;
      setState(() => _applying = false);
      await showCupertinoDialog<void>(
        context: context,
        builder: (ctx) => CupertinoAlertDialog(
          title: const Text('套用失敗'),
          content: const Text('請稍後再試一次'),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('好'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: ElementColors.background,
      navigationBar: const CupertinoNavigationBar(
        backgroundColor: ElementColors.background,
        border: null,
        previousPageTitle: '運動',
        middle: Text('本週計畫'),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.only(bottom: 32),
            children: [
              _header(),
              _weekStrip(),
              for (int i = 0; i < 7; i++) _daySection(i),
              _applyButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header() {
    final p = widget.profile;
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ElementColors.cardBg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${_plan.goal.label}・每週 ${_plan.trainingDays} 天',
            style: const TextStyle(
                color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            '重訓每組 ${_plan.repRange}・棒式類每組 ${_plan.holdRange}',
            style: const TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 4),
          Text(
            '${p.heightCm.toStringAsFixed(0)} cm・${p.weightKg.toStringAsFixed(1)} kg・${p.age} 歲',
            style: const TextStyle(color: Colors.white38, fontSize: 12),
          ),
          const Divider(height: 24, color: Colors.white12),
          for (final note in _plan.notes)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 2, right: 8),
                    child: Icon(CupertinoIcons.info_circle,
                        size: 16, color: ElementColors.lightUi),
                  ),
                  Expanded(
                    child: Text(note,
                        style: const TextStyle(color: Colors.white70, height: 1.4)),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// 一週總覽：每天一個圓點，實心 = 重訓、橘 = 有氧、空心 = 休息，今天加外框。
  /// 點圓點可以切換那天要不要運動。
  Widget _weekStrip() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('運動日（點圓圈切換運動 / 休息）',
              style: TextStyle(color: Colors.white70, fontSize: 14)),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (int i = 0; i < 7; i++) _stripDay(i),
            ],
          ),
        ],
      ),
    );
  }

  Widget _stripDay(int i) {
    final type = _plan.days[i].type;
    final isToday = _dateOf(i) == _today;
    final color = switch (type) {
      DayType.rest => Colors.transparent,
      DayType.cardio => ElementColors.cardio,
      _ => ElementColors.accent,
    };
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _toggleDay(i + 1),
      child: Column(
        children: [
          Text(_weekdays[i],
              style: TextStyle(
                  color: isToday ? Colors.white : Colors.white54,
                  fontWeight: isToday ? FontWeight.bold : FontWeight.normal)),
          const SizedBox(height: 6),
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
              border: Border.all(
                color: isToday
                    ? Colors.white
                    : (type == DayType.rest ? Colors.white24 : color),
                width: isToday ? 2 : 1,
              ),
            ),
            alignment: Alignment.center,
            child: Text('${_dateOf(i).day}',
                style: TextStyle(
                    color: type == DayType.rest ? Colors.white54 : Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
          ),
          const SizedBox(height: 4),
          Text(type.shortLabel,
              style: const TextStyle(color: Colors.white54, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _daySection(int i) {
    final day = _plan.days[i];
    final date = _dateOf(i);
    final isToday = date == _today;
    final isPast = date.isBefore(_today);

    final section = AppListSection(
      header: Row(
        children: [
          // 左邊「日期・類型 (+今天)」吃掉剩下的寬度，太窄才省略；右邊固定是預估時間
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    '週${_weekdays[i]} ${date.month}/${date.day}・${day.type.label}${isPast ? '（已過）' : ''}',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (isToday) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: ElementColors.accent,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text('今天',
                        style: TextStyle(color: Colors.white, fontSize: 11)),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text('約 ${day.estimatedMinutes} 分鐘'),
        ],
      ),
      children: [
        for (final e in day.items)
          CupertinoListTile(
            leading: CategoryIconTile(e.category),
            title: Text(e.name),
            subtitle: Text(_plan.doseOf(e)),
            trailing: const Icon(CupertinoIcons.info_circle, color: Colors.white54, size: 20),
            onTap: () => showExerciseGuide(context, e.exercise),
          ),
      ],
    );
    // 已經過去的日子套用時不會動，畫淡一點
    return isPast ? Opacity(opacity: 0.45, child: section) : section;
  }

  Widget _applyButton() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: SizedBox(
        width: double.infinity,
        child: CupertinoButton.filled(
          color: ElementColors.accent,
          onPressed: _applying ? null : _confirmApply,
          child: _applying
              ? const CupertinoActivityIndicator(color: Colors.white)
              : const Text('套用到本週訓練清單',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        ),
      ),
    );
  }
}
