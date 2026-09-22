import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

/// 折線圖元件：純顯示用，資料由外部（例如 exercise_screen）傳入。
/// [dailyValues] 與 [dayLabels] 長度必須一致，兩者是一一對應的
/// 「第 i 天的數值」和「第 i 天要顯示在 X 軸下面的文字」。
class LineChartSample2 extends StatefulWidget {
  const LineChartSample2({
    super.key,
    required this.dailyValues,
    required this.dayLabels,
  });

  final List<double> dailyValues;
  final List<String> dayLabels;

  @override
  State<LineChartSample2> createState() => _LineChartSample2State();
}

class _LineChartSample2State extends State<LineChartSample2> {
  final List<Color> gradientColors = [
    Colors.white,
    Colors.cyan,
  ];

  bool showAvg = false;

  List<FlSpot> get _spots => [
        for (int i = 0; i < widget.dailyValues.length; i++)
          FlSpot(i.toDouble(), widget.dailyValues[i]),
      ];

  double get _maxX =>
      widget.dailyValues.length > 1 ? (widget.dailyValues.length - 1).toDouble() : 1;

  double get _maxY {
    final maxVal = widget.dailyValues.isEmpty
        ? 0.0
        : widget.dailyValues.reduce((a, b) => a > b ? a : b);
    if (maxVal <= 0) return 40;
    final padded = maxVal * 1.2;
    final step = padded < 100 ? 10.0 : (padded < 500 ? 50.0 : 100.0);
    return (padded / step).ceil() * step;
  }

  double get _leftInterval => _maxY / 4;

  double get _average {
    if (widget.dailyValues.isEmpty) return 0;
    final sum = widget.dailyValues.reduce((a, b) => a + b);
    return sum / widget.dailyValues.length;
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: <Widget>[
        AspectRatio(
          aspectRatio: 1.70,
          child: Padding(
            padding: const EdgeInsets.only(
              right: 18,
              left: 12,
              top: 24,
              bottom: 12,
            ),
            child: LineChart(
              showAvg ? avgData() : mainData(),
            ),
          ),
        ),
        SizedBox(
          width: 60,
          height: 34,
          child: TextButton(
            onPressed: () {
              setState(() {
                showAvg = !showAvg;
              });
            },
            child: Text(
              '平均',
              style: TextStyle(
                fontSize: 12,
                color: showAvg
                    ? Colors.white.withValues(alpha: 0.5)
                    : Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget bottomTitleWidgets(double value, TitleMeta meta) {
    const style = TextStyle(
      fontWeight: FontWeight.bold,
      fontSize: 11,
      color: Colors.white70,
    );
    final index = value.toInt();
    if (index < 0 || index >= widget.dayLabels.length) {
      return const SizedBox.shrink();
    }
    return SideTitleWidget(
      meta: meta,
      child: Text(widget.dayLabels[index], style: style),
    );
  }

  Widget leftTitleWidgets(double value, TitleMeta meta) {
    const style = TextStyle(
      fontWeight: FontWeight.bold,
      fontSize: 12,
      color: Colors.white70,
    );
    if (value == meta.max) return const SizedBox.shrink();
    return Text(value.toInt().toString(), style: style, textAlign: TextAlign.left);
  }

  LineChartData mainData() {
    return LineChartData(
      gridData: FlGridData(
        show: true,
        drawVerticalLine: true,
        horizontalInterval: _leftInterval,
        verticalInterval: 1,
        getDrawingHorizontalLine: (value) {
          return const FlLine(
            color: Colors.white12,
            strokeWidth: 1,
          );
        },
        getDrawingVerticalLine: (value) {
          return const FlLine(
            color: Colors.white12,
            strokeWidth: 1,
          );
        },
      ),
      titlesData: FlTitlesData(
        show: true,
        rightTitles: const AxisTitles(
          sideTitles: SideTitles(showTitles: false),
        ),
        topTitles: const AxisTitles(
          sideTitles: SideTitles(showTitles: false),
        ),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 30,
            interval: 1,
            getTitlesWidget: bottomTitleWidgets,
          ),
        ),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            interval: _leftInterval,
            getTitlesWidget: leftTitleWidgets,
            reservedSize: 42,
          ),
        ),
      ),
      borderData: FlBorderData(
        show: true,
        border: Border.all(color: Colors.white24),
      ),
      minX: 0,
      maxX: _maxX,
      minY: 0,
      maxY: _maxY,
      lineBarsData: [
        LineChartBarData(
          spots: _spots,
          isCurved: true,
          gradient: LinearGradient(
            colors: gradientColors,
          ),
          barWidth: 4,
          isStrokeCapRound: true,
          dotData: FlDotData(
            show: true,
            getDotPainter: (spot, percent, bar, index) => FlDotCirclePainter(
              radius: 3.5,
              color: Colors.white,
              strokeWidth: 2,
              strokeColor: gradientColors.last,
            ),
          ),
          belowBarData: BarAreaData(
            show: true,
            gradient: LinearGradient(
              colors: gradientColors
                  .map((color) => color.withValues(alpha: 0.3))
                  .toList(),
            ),
          ),
        ),
      ],
    );
  }

  LineChartData avgData() {
    final avgSpots = [
      for (int i = 0; i < widget.dailyValues.length; i++) FlSpot(i.toDouble(), _average),
    ];
    return LineChartData(
      lineTouchData: const LineTouchData(enabled: false),
      gridData: FlGridData(
        show: true,
        drawHorizontalLine: true,
        verticalInterval: 1,
        horizontalInterval: _leftInterval,
        getDrawingVerticalLine: (value) {
          return const FlLine(
            color: Colors.white12,
            strokeWidth: 1,
          );
        },
        getDrawingHorizontalLine: (value) {
          return const FlLine(
            color: Colors.white12,
            strokeWidth: 1,
          );
        },
      ),
      titlesData: FlTitlesData(
        show: true,
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 30,
            getTitlesWidget: bottomTitleWidgets,
            interval: 1,
          ),
        ),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            getTitlesWidget: leftTitleWidgets,
            reservedSize: 42,
            interval: _leftInterval,
          ),
        ),
        topTitles: const AxisTitles(
          sideTitles: SideTitles(showTitles: false),
        ),
        rightTitles: const AxisTitles(
          sideTitles: SideTitles(showTitles: false),
        ),
      ),
      borderData: FlBorderData(
        show: true,
        border: Border.all(color: Colors.white24),
      ),
      minX: 0,
      maxX: _maxX,
      minY: 0,
      maxY: _maxY,
      lineBarsData: [
        LineChartBarData(
          spots: avgSpots,
          isCurved: true,
          gradient: LinearGradient(
            colors: [
              ColorTween(begin: gradientColors[0], end: gradientColors[1])
                  .lerp(0.2)!,
              ColorTween(begin: gradientColors[0], end: gradientColors[1])
                  .lerp(0.2)!,
            ],
          ),
          barWidth: 4,
          isStrokeCapRound: true,
          dotData: const FlDotData(
            show: false,
          ),
          belowBarData: BarAreaData(
            show: true,
            gradient: LinearGradient(
              colors: [
                ColorTween(begin: gradientColors[0], end: gradientColors[1])
                    .lerp(0.2)!
                    .withValues(alpha: 0.1),
                ColorTween(begin: gradientColors[0], end: gradientColors[1])
                    .lerp(0.2)!
                    .withValues(alpha: 0.1),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
