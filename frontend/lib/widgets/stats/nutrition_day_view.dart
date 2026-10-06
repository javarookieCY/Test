import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../models/nutrients.dart';
import '../../utils/constants.dart';
import '../../utils/nutrition_math.dart';
import '../../utils/nutrition_stats.dart';

/// 圓餅圖要看什麼：熱量 / 三大營養素的「各餐分布」，或三大營養素的熱量比例
enum PieMode { calories, protein, carbs, fat, macroShare }

extension PieModeInfo on PieMode {
  String get label => switch (this) {
        PieMode.calories => '熱量',
        PieMode.protein => '蛋白質',
        PieMode.carbs => '碳水',
        PieMode.fat => '脂肪',
        PieMode.macroShare => '比例',
      };

  String get unit => this == PieMode.protein || this == PieMode.carbs || this == PieMode.fat
      ? 'g'
      : 'kcal';
}

/// 圓餅圖的一片，也是下方圖例表的一列
class _Slice {
  const _Slice(this.title, this.color, this.value, this.valueText);
  final String title;
  final Color color;
  final double value;
  final String valueText;
}

/// 統計頁「單一天」的內容：圓餅圖（可切換熱量 / 營養素）+ 圖例表 + 營養素卡片。
/// 純顯示，資料由統計頁讀好傳進來（方便寫 widget test）。
class NutritionDayView extends StatefulWidget {
  const NutritionDayView({super.key, required this.day, this.targets});

  final DayNutrition day;

  /// 個人化目標；還沒填個人資料時是 null，營養素就只顯示數字不顯示進度
  final NutritionTargets? targets;

  @override
  State<NutritionDayView> createState() => _NutritionDayViewState();
}

class _NutritionDayViewState extends State<NutritionDayView> {
  static const _mealTitles = ['早餐', '午餐', '晚餐', '宵夜', '其他餐點'];
  static const _mealColors = [
    Color(0xFF3987E5),
    Color(0xFFD95926),
    Color(0xFF199E70),
    Color(0xFFD55181),
    Color(0xFFC98500),
  ];
  static const _proteinColor = Color(0xFF3987E5);
  static const _carbsColor = Color(0xFFC98500);
  static const _fatColor = Color(0xFFD95926);

  PieMode _mode = PieMode.calories;

  int get _totalCalories => widget.day.calories;

  /// 目前模式下每一片的資料（含 0 的那幾片，圖例表要全部列出）
  List<_Slice> get _slices {
    final d = widget.day;
    String fmt(double v) => NutrientRow.fmt(v);
    if (_mode == PieMode.macroShare) {
      final n = d.nutrients;
      _Slice macro(String title, Color color, double grams, int kcalPerG) => _Slice(
          title, color, grams * kcalPerG, '${fmt(grams)} g・${(grams * kcalPerG).round()} kcal');
      return [
        macro('蛋白質', _proteinColor, n.protein, 4),
        macro('碳水', _carbsColor, n.carbs, 4),
        macro('脂肪', _fatColor, n.fat, 9),
      ];
    }
    final slices = <_Slice>[];
    for (int i = 0; i < _mealTitles.length; i++) {
      final meal = _mealTitles[i];
      final n = d.nutrientsByMeal[meal] ?? Nutrients.zero;
      final v = switch (_mode) {
        PieMode.calories => (d.caloriesByMeal[meal] ?? 0).toDouble(),
        PieMode.protein => n.protein,
        PieMode.carbs => n.carbs,
        _ => n.fat,
      };
      slices.add(_Slice(meal, _mealColors[i], v, '${fmt(v)} ${_mode.unit}'));
    }
    return slices;
  }

  @override
  Widget build(BuildContext context) {
    final slices = _slices;
    final total = slices.fold(0.0, (s, e) => s + e.value);
    return Column(
      children: [
        _pieCard(slices, total),
        const SizedBox(height: 16),
        _legendTable(slices, total),
        const SizedBox(height: 16),
        _nutrientsCard(),
      ],
    );
  }

  Widget _pieCard(List<_Slice> slices, double total) {
    final hasData = total > 0;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ElementColors.cardBg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          SizedBox(
            width: double.infinity,
            child: CupertinoSlidingSegmentedControl<PieMode>(
              groupValue: _mode,
              thumbColor: ElementColors.accent,
              backgroundColor: ElementColors.background,
              children: {
                for (final m in PieMode.values)
                  m: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text(m.label,
                        style: const TextStyle(color: Colors.white, fontSize: 13)),
                  ),
              },
              onValueChanged: (m) {
                if (m != null) setState(() => _mode = m);
              },
            ),
          ),
          const SizedBox(height: 12),
          AspectRatio(
            aspectRatio: 1.3,
            child: Stack(
              alignment: Alignment.center,
              children: [
                PieChart(
                  duration: Duration.zero, // 不要切片的進場 / 切換動畫
                  PieChartData(
                    sectionsSpace: hasData ? 2 : 0,
                    centerSpaceRadius: 40,
                    // 滑鼠移上去 / 點擊都不放大切片
                    pieTouchData: PieTouchData(enabled: false),
                    sections: hasData ? _buildSections(slices, total) : _emptySections(),
                  ),
                ),
                _pieCenterLabel(hasData, total),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<PieChartSectionData> _buildSections(List<_Slice> slices, double total) {
    return [
      for (final s in slices)
        if (s.value > 0)
          PieChartSectionData(
            color: s.color,
            value: s.value,
            radius: 56,
            // 太小的切片不塞百分比進去，避免文字被裁切，交給下面的表格顯示精確數字
            title: s.value / total >= 0.08
                ? '${(s.value / total * 100).toStringAsFixed(0)}%'
                : '',
            titleStyle: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
    ];
  }

  /// 沒有任何紀錄時的佔位切片：畫一整圈淺灰色，讓圖表結構還在，只是沒有內容。
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

  /// 甜甜圈中間的文字：有資料就顯示總量，沒有就顯示「尚無紀錄」提示。
  Widget _pieCenterLabel(bool hasData, double total) {
    if (!hasData) {
      return const Text('尚無紀錄', style: TextStyle(color: Colors.white38, fontSize: 13));
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          _mode.unit == 'g' ? NutrientRow.fmt(total) : '${total.round()}',
          style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
        ),
        Text(_mode.unit, style: const TextStyle(color: Colors.white54, fontSize: 11)),
      ],
    );
  }

  /// 圖例表格：色塊 + 名稱 + 數值 + 佔比，讓辨識不必只靠圓餅圖上的顏色。
  Widget _legendTable(List<_Slice> slices, double total) {
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
          for (final s in slices)
            _legendRow(
              color: s.color,
              title: s.title,
              valueText: s.valueText,
              percent: total == 0 ? 0 : s.value / total * 100,
            ),
        ],
      ),
    );
  }

  TableRow _legendRow({
    required Color color,
    required String title,
    required String valueText,
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
          child: Text(valueText,
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

  /// 營養素卡片：每一項是「數值 / 目標」加一條進度條。
  /// 熱量與鈉超過時進度條變紅，並加上「超過目標 / 超過上限」的文字。
  Widget _nutrientsCard() {
    final n = widget.day.nutrients;
    final t = widget.targets;
    final (pPct, cPct, fPct) = macroCaloriePercent(n);
    final hasMacros = pPct + cPct + fPct > 0;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      decoration: BoxDecoration(
        color: ElementColors.cardBg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('營養素', style: kGreyBoldText),
          const SizedBox(height: 12),
          NutrientRow(
            label: '熱量',
            value: _totalCalories.toDouble(),
            target: t?.calories.toDouble(),
            unit: 'kcal',
            warnWhenOver: true,
          ),
          NutrientRow(
            label: '蛋白質',
            value: n.protein,
            target: t?.proteinG.toDouble(),
            unit: 'g',
            note: hasMacros ? '佔熱量 $pPct%' : null,
          ),
          NutrientRow(
            label: '碳水',
            value: n.carbs,
            target: t?.carbsG.toDouble(),
            unit: 'g',
            note: hasMacros ? '佔熱量 $cPct%' : null,
          ),
          NutrientRow(
            label: '脂肪',
            value: n.fat,
            target: t?.fatG.toDouble(),
            unit: 'g',
            note: hasMacros ? '佔熱量 $fPct%' : null,
          ),
          NutrientRow(
            label: '膳食纖維',
            value: n.fiber,
            target: kFiberTargetG.toDouble(),
            unit: 'g',
          ),
          NutrientRow(
            label: '鈉',
            value: n.sodium,
            target: kSodiumLimitMg.toDouble(),
            unit: 'mg',
            warnWhenOver: true,
            isLimit: true,
          ),
        ],
      ),
    );
  }
}

/// 營養素的一列：名稱、數值 / 目標、進度條。
/// [isLimit] = 目標其實是「上限」（例如鈉）；[warnWhenOver] = 超過時要警示。
class NutrientRow extends StatelessWidget {
  const NutrientRow({
    super.key,
    required this.label,
    required this.value,
    required this.unit,
    this.target,
    this.note,
    this.warnWhenOver = false,
    this.isLimit = false,
  });

  final String label;
  final double value;
  final double? target;
  final String unit;
  final String? note;
  final bool warnWhenOver;
  final bool isLimit;

  /// 10 以上取整數，小於 10 留一位小數（例如 3.5 g 纖維）
  static String fmt(double v) =>
      v >= 10 || v == v.roundToDouble() ? v.round().toString() : v.toStringAsFixed(1);

  @override
  Widget build(BuildContext context) {
    final t = target;
    final over = warnWhenOver && t != null && t > 0 && value > t;
    final barColor = over ? ElementColors.warning : ElementColors.accent;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(label, style: const TextStyle(color: Colors.white)),
              if (note != null) ...[
                const SizedBox(width: 6),
                Text(note!, style: const TextStyle(color: Colors.white38, fontSize: 11)),
              ],
              const Spacer(),
              if (over) ...[
                const Icon(Icons.warning_amber_rounded,
                    size: 14, color: ElementColors.warning),
                const SizedBox(width: 2),
                Text(isLimit ? '超過上限 ' : '超過目標 ',
                    style: const TextStyle(color: Colors.white70, fontSize: 12)),
              ],
              Text(
                t == null
                    ? '${fmt(value)} $unit'
                    : '${fmt(value)} / ${fmt(t)} $unit${isLimit ? '（上限）' : ''}',
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
          if (t != null && t > 0) ...[
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: (value / t).clamp(0.0, 1.0),
                minHeight: 6,
                backgroundColor: ElementColors.accentDim,
                valueColor: AlwaysStoppedAnimation(barColor),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
