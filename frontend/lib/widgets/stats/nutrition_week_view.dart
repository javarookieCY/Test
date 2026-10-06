import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../utils/constants.dart';
import '../../utils/nutrition_math.dart';
import '../../utils/nutrition_stats.dart';
import 'nutrition_day_view.dart' show NutrientRow;

/// 長條圖要畫哪一項
enum WeekMetric { calories, protein, carbs, fat }

extension WeekMetricInfo on WeekMetric {
  String get label => switch (this) {
        WeekMetric.calories => '熱量',
        WeekMetric.protein => '蛋白質',
        WeekMetric.carbs => '碳水',
        WeekMetric.fat => '脂肪',
      };

  String get unit => this == WeekMetric.calories ? 'kcal' : 'g';

  double valueOf(DayNutrition d) => switch (this) {
        WeekMetric.calories => d.calories.toDouble(),
        WeekMetric.protein => d.nutrients.protein,
        WeekMetric.carbs => d.nutrients.carbs,
        WeekMetric.fat => d.nutrients.fat,
      };

  double? targetOf(NutritionTargets? t) => t == null
      ? null
      : switch (this) {
          WeekMetric.calories => t.calories.toDouble(),
          WeekMetric.protein => t.proteinG.toDouble(),
          WeekMetric.carbs => t.carbsG.toDouble(),
          WeekMetric.fat => t.fatG.toDouble(),
        };
}

/// 長條圖 Y 軸上限：資料（含目標線）最大值再留 15% 空間，對齊到好讀的刻度
double niceMaxY(double maxValue) {
  if (maxValue <= 0) return 100;
  final padded = maxValue * 1.15;
  final magnitude = math.pow(10, (math.log(padded) / math.ln10).floor()).toDouble();
  final step = padded / magnitude <= 2
      ? magnitude / 4
      : padded / magnitude <= 5
          ? magnitude / 2
          : magnitude;
  return (padded / step).ceil() * step;
}

/// 統計頁「一週」的內容：每日長條圖（可切換熱量 / 三大營養素）+ 平均 + 每日明細表。
class NutritionWeekView extends StatefulWidget {
  const NutritionWeekView({
    super.key,
    required this.days,
    required this.today,
    this.targets,
  });

  final List<DayNutrition> days; // 由舊到新，通常 7 天
  final DateTime today;
  final NutritionTargets? targets;

  @override
  State<NutritionWeekView> createState() => _NutritionWeekViewState();
}

class _NutritionWeekViewState extends State<NutritionWeekView> {
  static const _weekdays = ['一', '二', '三', '四', '五', '六', '日'];

  WeekMetric _metric = WeekMetric.calories;

  bool _isToday(DateTime d) =>
      d.year == widget.today.year && d.month == widget.today.month && d.day == widget.today.day;

  String _shortDate(DateTime d) => _isToday(d) ? '今天' : '${d.month}/${d.day}';

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _chartCard(),
        const SizedBox(height: 16),
        _averageCard(),
        const SizedBox(height: 16),
        _dailyTable(),
      ],
    );
  }

  BoxDecoration get _card => BoxDecoration(
        color: ElementColors.cardBg,
        borderRadius: BorderRadius.circular(10),
      );

  Widget _chartCard() {
    final values = widget.days.map(_metric.valueOf).toList();
    final target = _metric.targetOf(widget.targets);
    final maxY = niceMaxY([...values, target ?? 0].reduce(math.max));

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 16, 16, 12),
      decoration: _card,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Row(
              children: [
                Text('每日${_metric.label}（${_metric.unit}）', style: kGreyBoldText),
                const Spacer(),
                // 虛線圖例：跟圖上的目標線同一個樣子
                if (target != null) ...[
                  const _DashSwatch(),
                  const SizedBox(width: 6),
                  Text('目標 ${target.round()}', style: kGreyBoldText),
                ],
              ],
            ),
          ),
          const SizedBox(height: 10),
          CupertinoSlidingSegmentedControl<WeekMetric>(
            groupValue: _metric,
            thumbColor: ElementColors.accent,
            backgroundColor: ElementColors.background,
            children: {
              for (final m in WeekMetric.values)
                m: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(m.label,
                      style: const TextStyle(color: Colors.white, fontSize: 13)),
                ),
            },
            onValueChanged: (m) {
              if (m != null) setState(() => _metric = m);
            },
          ),
          const SizedBox(height: 20),
          AspectRatio(
            aspectRatio: 1.5,
            child: BarChart(
              BarChartData(
                minY: 0,
                maxY: maxY,
                alignment: BarChartAlignment.spaceAround,
                borderData: FlBorderData(show: false),
                gridData: FlGridData(
                  drawVerticalLine: false,
                  horizontalInterval: maxY / 4,
                  getDrawingHorizontalLine: (_) =>
                      const FlLine(color: Colors.white12, strokeWidth: 1),
                ),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      interval: maxY / 4,
                      getTitlesWidget: (v, meta) => v == meta.max
                          ? const SizedBox.shrink()
                          : Text(v.round().toString(),
                              style: const TextStyle(color: Colors.white54, fontSize: 11)),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 44, // 兩行（星期 + 日期），中文字行高較高

                      getTitlesWidget: (v, meta) {
                        final i = v.toInt();
                        if (i < 0 || i >= widget.days.length) return const SizedBox.shrink();
                        final d = widget.days[i].date;
                        return SideTitleWidget(
                          meta: meta,
                          child: Text(
                            '${_weekdays[d.weekday - 1]}\n${_shortDate(d)}',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: _isToday(d) ? Colors.white : Colors.white54,
                              fontSize: 11,
                              fontWeight: _isToday(d) ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                extraLinesData: target == null
                    ? null
                    : ExtraLinesData(horizontalLines: [
                        // 目標數字寫在圖下方的說明，不放線上（會跟長條撞在一起）
                        HorizontalLine(
                          y: target,
                          color: Colors.white54,
                          strokeWidth: 1,
                          dashArray: [6, 4],
                        ),
                      ]),
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    fitInsideHorizontally: true,
                    fitInsideVertically: true,
                    getTooltipColor: (_) => ElementColors.background,
                    tooltipBorder: const BorderSide(color: Colors.white24),
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      final d = widget.days[group.x];
                      return BarTooltipItem(
                        '${d.date.month}/${d.date.day}\n',
                        const TextStyle(color: Colors.white54, fontSize: 11),
                        children: [
                          TextSpan(
                            text: d.hasData
                                ? '${rod.toY.round()} ${_metric.unit}'
                                : '沒有紀錄',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.bold),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                barGroups: [
                  for (int i = 0; i < values.length; i++)
                    BarChartGroupData(
                      x: i,
                      barRods: [
                        BarChartRodData(
                          toY: values[i],
                          width: 18,
                          color: ElementColors.accent,
                          borderRadius:
                              const BorderRadius.vertical(top: Radius.circular(4)),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _averageCard() {
    final avg = PeriodAverage.of(widget.days);
    final t = widget.targets;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      decoration: _card,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            avg.loggedDays == 0
                ? '每日平均（這 ${widget.days.length} 天都沒有紀錄）'
                : '每日平均（${widget.days.length} 天中有 ${avg.loggedDays} 天有紀錄）',
            style: kGreyBoldText,
          ),
          const SizedBox(height: 12),
          NutrientRow(
            label: '熱量',
            value: avg.calories.toDouble(),
            target: t?.calories.toDouble(),
            unit: 'kcal',
            warnWhenOver: true,
          ),
          NutrientRow(
              label: '蛋白質', value: avg.nutrients.protein, target: t?.proteinG.toDouble(), unit: 'g'),
          NutrientRow(
              label: '碳水', value: avg.nutrients.carbs, target: t?.carbsG.toDouble(), unit: 'g'),
          NutrientRow(
              label: '脂肪', value: avg.nutrients.fat, target: t?.fatG.toDouble(), unit: 'g'),
          NutrientRow(
              label: '膳食纖維',
              value: avg.nutrients.fiber,
              target: kFiberTargetG.toDouble(),
              unit: 'g'),
          NutrientRow(
            label: '鈉',
            value: avg.nutrients.sodium,
            target: kSodiumLimitMg.toDouble(),
            unit: 'mg',
            warnWhenOver: true,
            isLimit: true,
          ),
        ],
      ),
    );
  }

  /// 長條圖的表格版：每天一列，所有數字都看得到（不用一根根點）
  Widget _dailyTable() {
    const head = TextStyle(color: Colors.white54, fontSize: 12);
    const cell = TextStyle(color: Colors.white70, fontSize: 12);
    Widget c(String s, TextStyle style, {bool right = true}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(s, style: style, textAlign: right ? TextAlign.right : TextAlign.left),
        );
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      decoration: _card,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('每日明細', style: kGreyBoldText),
          const SizedBox(height: 4),
          Table(
            columnWidths: const {0: FlexColumnWidth(1.3)},
            border: const TableBorder(
                horizontalInside: BorderSide(color: Colors.white12, width: 1)),
            children: [
              TableRow(children: [
                c('日期', head, right: false),
                c('熱量 kcal', head),
                c('蛋白質 g', head),
                c('碳水 g', head),
                c('脂肪 g', head),
              ]),
              for (final d in widget.days)
                TableRow(children: [
                  c('${_shortDate(d.date)}（${_weekdays[d.date.weekday - 1]}）', cell,
                      right: false),
                  if (d.hasData) ...[
                    c('${d.calories}', cell),
                    c(NutrientRow.fmt(d.nutrients.protein), cell),
                    c(NutrientRow.fmt(d.nutrients.carbs), cell),
                    c(NutrientRow.fmt(d.nutrients.fat), cell),
                  ] else
                    for (int i = 0; i < 4; i++)
                      c('–', const TextStyle(color: Colors.white24, fontSize: 12)),
                ]),
            ],
          ),
        ],
      ),
    );
  }
}

/// 標題旁的小虛線，說明圖上的虛線是目標
class _DashSwatch extends StatelessWidget {
  const _DashSwatch();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int i = 0; i < 3; i++)
          Container(
            width: 5,
            height: 2,
            margin: const EdgeInsets.only(right: 3),
            color: Colors.white54,
          ),
      ],
    );
  }
}
