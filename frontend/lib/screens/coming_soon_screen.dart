import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../db_helper.dart';
import '../utils/constants.dart';

/// 「統計」分頁：專門放圖表用的頁面。
/// 目前放一張圓餅圖，顯示今天各餐（早餐/午餐/晚餐/宵夜/其他餐點）的卡路里分布。
/// 今天還沒有紀錄時，圖表本身仍會顯示（只是切片是空的灰圈），不會整塊被文字取代。
class ComingSoonScreen extends StatefulWidget {
  const ComingSoonScreen({super.key, this.refreshTick = 0});

  /// RootShell 每次切換到這一頁就會 +1，讓頁面知道要重新讀資料庫
  /// （因為 PageView 用 children 一次建好三頁，這頁不會自動感知到別頁改了飲食紀錄）。
  final int refreshTick;

  @override
  State<ComingSoonScreen> createState() => _ComingSoonScreenState();
}

class _ComingSoonScreenState extends State<ComingSoonScreen> {
  static const _mealTitles = ['早餐', '午餐', '晚餐', '宵夜', '其他餐點'];
  static const _mealColors = [
    Color(0xFF3987E5), 
    Color(0xFFD95926), 
    Color(0xFF199E70), 
    Color(0xFFD55181), 
    Color(0xFFC98500), 
  ];

  Map<String, int> _caloriesByMeal = {for (final t in _mealTitles) t: 0};
  int _touchedIndex = -1;

  int get _totalCalories => _caloriesByMeal.values.fold(0, (a, b) => a + b);

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant ComingSoonScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshTick != widget.refreshTick) {
      _load();
    }
  }

  Future<void> _load() async {
    final now = DateTime.now();
    final dateStr = '${now.year}-${now.month}-${now.day}';
    final rows = await DBHelper.instance.getMealFoodsByDate(dateStr);

    final totals = {for (final t in _mealTitles) t: 0};
    for (final row in rows) {
      final title = row['meal_title'] as String;
      final calories = row['calories'] as int;
      if (totals.containsKey(title)) {
        totals[title] = totals[title]! + calories;
      }
    }

    if (!mounted) return;
    setState(() => _caloriesByMeal = totals);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ElementColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // 最上方：只顯示「今天」
            const Padding(
              padding: EdgeInsets.fromLTRB(15, 15, 15, 0),
              child: Row(
                children: [Text('今天', style: kTitleText)],
              ),
            ),
            // 中間：圖表 + 圖例表格
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(15, 16, 15, 24),
                child: Column(
                  children: [
                    _pieCard(),
                    const SizedBox(height: 16),
                    _legendTable(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pieCard() {
    final hasData = _totalCalories > 0;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ElementColors.cardBg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: AspectRatio(
        aspectRatio: 1.3,
        child: Stack(
          alignment: Alignment.center,
          children: [
            PieChart(
              PieChartData(
                sectionsSpace: hasData ? 2 : 0,
                centerSpaceRadius: 40,
                pieTouchData: PieTouchData(
                  touchCallback: (event, response) {
                    setState(() {
                      final section = response?.touchedSection;
                      _touchedIndex = (!event.isInterestedForInteractions || section == null)
                          ? -1
                          : section.touchedSectionIndex;
                    });
                  },
                ),
                sections: hasData ? _buildSections() : _emptySections(),
              ),
            ),
            _pieCenterLabel(hasData),
          ],
        ),
      ),
    );
  }

  List<PieChartSectionData> _buildSections() {
    final total = _totalCalories;
    final sections = <PieChartSectionData>[];
    for (int i = 0; i < _mealTitles.length; i++) {
      final value = _caloriesByMeal[_mealTitles[i]] ?? 0;
      if (value <= 0) continue;
      final isTouched = i == _touchedIndex;
      final percent = value / total * 100;
      sections.add(
        PieChartSectionData(
          color: _mealColors[i],
          value: value.toDouble(),
          radius: isTouched ? 64 : 56,
          // 太小的切片不塞百分比進去，避免文字被裁切，交給下面的表格顯示精確數字
          title: percent >= 8 ? '${percent.toStringAsFixed(0)}%' : '',
          titleStyle: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      );
    }
    return sections;
  }

  /// 今天沒有任何紀錄時的佔位切片：畫一整圈淺灰色，讓圖表結構還在，只是沒有內容。
  List<PieChartSectionData> _emptySections() {
    return [
      PieChartSectionData(
        color: Colors.white12,
        value: 1,
        radius: 56,
        title: '',
      ),
    ];
  }

  /// 甜甜圈中間的文字：有紀錄就顯示今天總熱量，沒有就顯示「尚無紀錄」提示。
  Widget _pieCenterLabel(bool hasData) {
    if (!hasData) {
      return const Text('尚無紀錄', style: TextStyle(color: Colors.white38, fontSize: 13));
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$_totalCalories',
          style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const Text('kcal', style: TextStyle(color: Colors.white54, fontSize: 11)),
      ],
    );
  }

  /// 圖例表格：色塊 + 餐別名稱 + 熱量 + 佔比，讓辨識不必只靠圓餅圖上的顏色。
  Widget _legendTable() {
    final total = _totalCalories;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: ElementColors.cardBg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Table(
        columnWidths: const {
          0: FixedColumnWidth(28),
          1: FlexColumnWidth(),
          2: IntrinsicColumnWidth(),
          3: IntrinsicColumnWidth(),
        },
        children: [
          for (int i = 0; i < _mealTitles.length; i++)
            _legendRow(
              color: _mealColors[i],
              title: _mealTitles[i],
              calories: _caloriesByMeal[_mealTitles[i]] ?? 0,
              percent: total == 0 ? 0 : (_caloriesByMeal[_mealTitles[i]] ?? 0) / total * 100,
            ),
        ],
      ),
    );
  }

  TableRow _legendRow({
    required Color color,
    required String title,
    required int calories,
    required double percent,
  }) {
    return TableRow(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          child: Text(title, style: const TextStyle(color: Colors.white)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Text('$calories kcal',
              style: const TextStyle(color: Colors.white70, fontSize: 12)),
        ),
        Padding(
          padding: const EdgeInsets.only(left: 8, top: 10, bottom: 10),
          child: Text('${percent.toStringAsFixed(0)}%',
              style: const TextStyle(color: Colors.white54, fontSize: 12)),
        ),
      ],
    );
  }
}
