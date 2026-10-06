import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../db_helper.dart';
import '../utils/constants.dart';
import '../utils/nutrition_math.dart';
import '../utils/nutrition_stats.dart';
import '../widgets/common/cupertino_day_picker.dart';
import '../widgets/stats/nutrition_day_view.dart';
import '../widgets/stats/nutrition_week_view.dart';

/// 「統計」分頁。右上角一顆日期按鈕（預設「今天」），點開是一個小清單：
/// 最近 7 天、一週（本週一～日）、選擇其他日期…
/// - 單一天：圓餅圖（熱量 / 營養素可切換）+ 營養素（熱量、三大營養素、纖維、鈉）對目標的進度
/// - 一週：每日長條圖（可切換熱量 / 三大營養素）+ 每日平均 + 每日明細表
class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key, this.refreshTick = 0});

  /// RootShell 每次切換到這一頁就會 +1，讓頁面知道要重新讀資料庫
  /// （因為 PageView 用 children 一次建好三頁，這頁不會自動感知到別頁改了飲食紀錄）。
  final int refreshTick;

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

/// 日期清單裡的一個選項：某一天，或一週
class _RangeChoice {
  const _RangeChoice.day(this.day) : isWeek = false;
  const _RangeChoice.week()
      : isWeek = true,
        day = null;
  const _RangeChoice.pickOther()
      : isWeek = false,
        day = null;

  final bool isWeek;
  final DateTime? day; // 「選擇其他日期…」時是 null
}

class _StatsScreenState extends State<StatsScreen> {
  static const _weekdays = ['一', '二', '三', '四', '五', '六', '日'];

  StatsRange _range = StatsRange.day;
  DateTime _day = dateOnly(DateTime.now());
  late List<DayNutrition> _days = _emptyDays();
  NutritionTargets? _targets;
  int _reqId = 0; // 防止較舊的查詢覆蓋較新的結果

  DateTime get _today => dateOnly(DateTime.now());

  List<DateTime> get _dates => datesForRange(_range, DateTime.now(), day: _day);

  // 讀 DB 前先放一份全 0 的資料，畫面結構不會因為切換範圍而跳動
  List<DayNutrition> _emptyDays() => [for (final d in _dates) DayNutrition(date: d)];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant StatsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshTick != widget.refreshTick) {
      _load();
    }
  }

  Future<void> _load() async {
    final req = ++_reqId;
    final dates = _dates;
    final rows = await DBHelper.instance.getMealFoodsByDates(dates.map(dateKey).toList());
    final profile = await DBHelper.instance.getUserProfile();
    if (!mounted || req != _reqId) return;
    setState(() {
      _days = groupByDay(dates, rows);
      _targets = profile?.targets;
    });
  }

  void _show(StatsRange range, DateTime day) {
    setState(() {
      _range = range;
      _day = dateOnly(day);
      _days = _emptyDays();
    });
    _load();
  }

  Future<void> _onChoice(_RangeChoice c) async {
    if (c.isWeek) return _show(StatsRange.week, _today);
    if (c.day != null) return _show(StatsRange.day, c.day!);
    final now = DateTime.now();
    final picked = await showCupertinoDayPicker(
      context,
      initial: _day,
      minimumDate: DateTime(now.year - 5),
      maximumDate: DateTime(now.year + 1, 12, 31),
    );
    if (picked != null && mounted) _show(StatsRange.day, picked);
  }

  String _dayLabel(DateTime d) =>
      d == _today ? '今天' : '${d.month}/${d.day}（${_weekdays[d.weekday - 1]}）';

  /// 日期按鈕上的文字
  String get _buttonLabel {
    if (_range == StatsRange.week) {
      final ds = _dates;
      return '一週 ${ds.first.month}/${ds.first.day}–${ds.last.month}/${ds.last.day}';
    }
    return _dayLabel(_day);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ElementColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(15, 10, 8, 0),
              child: Row(
                children: [
                  const Text('統計', style: kTitleText),
                  const Spacer(),
                  _rangeButton(),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(15, 8, 15, 24),
                child: _range == StatsRange.week
                    ? NutritionWeekView(
                        days: _days,
                        today: DateTime.now(),
                        targets: _targets,
                      )
                    : NutritionDayView(
                        key: ValueKey(_days.first.date),
                        day: _days.first,
                        targets: _targets,
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 「今天 ▾」按鈕：點開是最近 7 天 + 一週 + 選擇其他日期 的小清單
  Widget _rangeButton() {
    final isWeek = _range == StatsRange.week;
    PopupMenuItem<_RangeChoice> item(_RangeChoice value, String text, bool selected) =>
        PopupMenuItem(
          value: value,
          height: 40,
          child: Row(
            children: [
              SizedBox(
                width: 24,
                child: selected
                    ? const Icon(CupertinoIcons.checkmark_alt,
                        size: 18, color: ElementColors.lightUi)
                    : null,
              ),
              Text(text, style: const TextStyle(color: Colors.white)),
            ],
          ),
        );
    return PopupMenuButton<_RangeChoice>(
      color: ElementColors.cardBg,
      position: PopupMenuPosition.under,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: Colors.white12),
      ),
      onSelected: _onChoice,
      itemBuilder: (_) => [
        for (final d in recentDays(DateTime.now()))
          item(_RangeChoice.day(d), _dayLabel(d), !isWeek && d == _day),
        const PopupMenuDivider(),
        item(const _RangeChoice.week(), '一週（本週一～日）', isWeek),
        item(const _RangeChoice.pickOther(), '選擇其他日期…',
            !isWeek && !recentDays(DateTime.now()).contains(_day)),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: ElementColors.cardBg,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_buttonLabel, style: const TextStyle(color: Colors.white, fontSize: 15)),
            const SizedBox(width: 4),
            const Icon(CupertinoIcons.chevron_down, size: 14, color: Colors.white70),
          ],
        ),
      ),
    );
  }
}
