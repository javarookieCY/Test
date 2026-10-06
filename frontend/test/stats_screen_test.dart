// 統計頁的畫面測試。整頁測試用記憶體裡的 SQLite（每個測試一個新的），
// 並用 runAsync 讓真實的 DB 非同步跑完；Day / Week 兩個 view 另外直接餵資料測細節。

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/db_helper.dart';
import 'package:flutter_application_1/models/nutrients.dart';
import 'package:flutter_application_1/screens/stats_screen.dart';
import 'package:flutter_application_1/utils/nutrition_math.dart';
import 'package:flutter_application_1/utils/nutrition_stats.dart';
import 'package:flutter_application_1/widgets/stats/nutrition_day_view.dart';
import 'package:flutter_application_1/widgets/stats/nutrition_week_view.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart' show inMemoryDatabasePath;

const _targets = NutritionTargets(
    bmr: 1700, tdee: 2300, calories: 2000, proteinG: 140, carbsG: 220, fatG: 60);

Widget _wrap(Widget child) => MaterialApp(
      home: Scaffold(body: SingleChildScrollView(child: child)),
    );

void _phoneSize(WidgetTester tester) {
  tester.view.physicalSize = const Size(1170, 2532); // 390 × 844
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

/// 讓真實的 DB 呼叫跑完：反覆「真的等一下 → 推進假時鐘」
Future<void> _settleDb(WidgetTester tester) async {
  for (int i = 0; i < 8; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
    await tester.pump();
  }
}

Future<void> _pumpStats(WidgetTester tester) async {
  _phoneSize(tester);
  await tester.pumpWidget(const MaterialApp(home: StatsScreen()));
  await _settleDb(tester);
}

Future<void> _tapAndLoad(WidgetTester tester, Finder f) async {
  await tester.tap(f);
  await tester.pumpAndSettle();
  await _settleDb(tester);
}

void main() {
  setUp(() => DBHelper.instance.openForTest(inMemoryDatabasePath));

  group('統計頁', () {
    String label(DateTime d) => '${d.month}/${d.day}（${'一二三四五六日'[d.weekday - 1]}）';

    testWidgets('預設看今天：只有一顆「今天」按鈕，沒有昨天 / 明天 / 自訂分段；空圓餅與營養素卡片', (tester) async {
      await _pumpStats(tester);
      expect(find.text('今天'), findsOneWidget);
      for (final gone in ['昨天', '明天', '自訂']) {
        expect(find.text(gone), findsNothing, reason: gone);
      }
      expect(find.text('尚無紀錄'), findsOneWidget);
      expect(find.text('營養素'), findsOneWidget);
      expect(find.byType(PieChart), findsOneWidget);
    });

    testWidgets('點「今天」跳出小清單：最近 7 天 + 一週 + 選擇其他日期', (tester) async {
      await _pumpStats(tester);
      await tester.tap(find.text('今天'));
      await tester.pumpAndSettle();

      final now = DateTime.now();
      for (int i = 1; i < 7; i++) {
        final d = DateTime(now.year, now.month, now.day - i);
        expect(find.text(label(d)), findsOneWidget, reason: label(d));
      }
      expect(find.text('一週（本週一～日）'), findsOneWidget);
      expect(find.text('選擇其他日期…'), findsOneWidget);
    });

    testWidgets('從清單選「一週」換成長條圖，再選某一天變回圓餅圖', (tester) async {
      await _pumpStats(tester);
      await _tapAndLoad(tester, find.text('今天'));
      await _tapAndLoad(tester, find.text('一週（本週一～日）'));
      expect(find.byType(BarChart), findsOneWidget);
      expect(find.byType(PieChart), findsNothing);
      expect(find.textContaining('一週 '), findsOneWidget); // 按鈕變成「一週 10/5–10/11」
      expect(find.text('每日明細'), findsOneWidget);

      final now = DateTime.now();
      final twoDaysAgo = DateTime(now.year, now.month, now.day - 2);
      await _tapAndLoad(tester, find.textContaining('一週 '));
      await _tapAndLoad(tester, find.text(label(twoDaysAgo)).last); // 清單在最上層
      expect(find.byType(PieChart), findsOneWidget);
      expect(find.byType(BarChart), findsNothing);
      expect(find.text(label(twoDaysAgo)), findsOneWidget); // 按鈕顯示那天
    });

    testWidgets('從資料庫讀出飲食紀錄：今天的營養素、圓餅切換營養素、昨天、一週長條圖', (tester) async {
      final now = DateTime.now();
      final yesterdayDate = DateTime(now.year, now.month, now.day - 1);
      await tester.runAsync(() async {
        final db = DBHelper.instance;
        await db.upsertMealFood(dateKey(now), '早餐', '燕麥', 380, 1,
            const Nutrients(protein: 13, carbs: 66, fat: 7, fiber: 10, sodium: 5));
        await db.upsertMealFood(dateKey(now), '午餐', '雞胸便當', 720, 1,
            const Nutrients(protein: 45, carbs: 90, fat: 20, fiber: 6, sodium: 1500));
        await db.upsertMealFood(dateKey(yesterdayDate), '晚餐', '牛肉麵', 650, 1,
            const Nutrients(protein: 30, carbs: 80, fat: 22, sodium: 2600));
      });

      await _pumpStats(tester);
      expect(find.text('1100'), findsOneWidget); // 今天總熱量（圓餅中間）
      expect(find.text('58 g'), findsOneWidget); // 蛋白質 13 + 45（還沒填個人資料，只顯示數字）
      expect(find.text('16 / 25 g'), findsOneWidget); // 纖維

      // 圓餅切成蛋白質：中間是 58 g，圖例是各餐的蛋白質
      await tester.tap(find.text('蛋白質').first);
      await tester.pumpAndSettle();
      expect(find.text('58'), findsOneWidget);
      expect(find.text('13 g'), findsOneWidget);
      expect(find.text('45 g'), findsOneWidget);

      await _tapAndLoad(tester, find.text('今天'));
      await _tapAndLoad(tester, find.text(label(yesterdayDate)));
      expect(find.text('650'), findsOneWidget);
      expect(find.text('超過上限 '), findsOneWidget); // 鈉 2600 > 2400

      // 一週 = 本週一到週日：今天在第 weekday 根；昨天只有在今天不是週一時才在這週
      await _tapAndLoad(tester, find.text(label(yesterdayDate)));
      await _tapAndLoad(tester, find.text('一週（本週一～日）'));
      final chart = tester.widget<BarChart>(find.byType(BarChart));
      final expected = List<double>.filled(7, 0);
      expected[now.weekday - 1] = 1100;
      if (now.weekday > 1) expected[now.weekday - 2] = 650;
      expect(chart.data.barGroups.map((g) => g.barRods.single.toY), expected);
      final logged = now.weekday > 1 ? 2 : 1;
      expect(find.text('每日平均（7 天中有 $logged 天有紀錄）'), findsOneWidget);
    });

    testWidgets('「選擇其他日期…」跳出中文日期滾輪，取消後維持原本的日子', (tester) async {
      await _pumpStats(tester);
      await tester.tap(find.text('今天'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('選擇其他日期…'));
      await tester.pumpAndSettle();
      expect(find.text('選擇日期'), findsOneWidget);
      expect(find.textContaining('月'), findsWidgets); // 月份是「10月」不是「October」
      expect(find.text('October'), findsNothing);

      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      expect(find.text('選擇日期'), findsNothing);
      expect(find.text('今天'), findsOneWidget);
      expect(find.byType(PieChart), findsOneWidget);
    });
  });

  group('NutritionDayView 圓餅圖', () {
    final day = DayNutrition.fromRows(DateTime(2026, 10, 7), [
      {'date': '2026-10-7', 'meal_title': '早餐', 'calories': 400, 'protein': 20.0, 'carbs': 50.0, 'fat': 10.0},
      {'date': '2026-10-7', 'meal_title': '晚餐', 'calories': 600, 'protein': 40.0, 'carbs': 50.0, 'fat': 20.0},
    ]);

    testWidgets('沒有動畫、滑鼠移上去 / 點擊不會放大切片', (tester) async {
      _phoneSize(tester);
      await tester.pumpWidget(_wrap(NutritionDayView(day: day, targets: _targets)));
      final pie = tester.widget<PieChart>(find.byType(PieChart));
      expect(pie.duration, Duration.zero);
      expect(pie.data.pieTouchData.enabled, isFalse);
      expect(pie.data.sections.map((s) => s.radius).toSet(), {56});
    });

    testWidgets('切換「碳水」：各餐的碳水分布', (tester) async {
      _phoneSize(tester);
      await tester.pumpWidget(_wrap(NutritionDayView(day: day, targets: _targets)));
      await tester.tap(find.text('碳水').first);
      await tester.pumpAndSettle();
      final pie = tester.widget<PieChart>(find.byType(PieChart));
      expect(pie.data.sections.map((s) => s.value), [50, 50]);
      expect(find.text('100'), findsOneWidget); // 中間總量
      expect(find.text('50 g'), findsNWidgets(2));
    });

    testWidgets('切換「比例」：三大營養素提供的熱量佔比', (tester) async {
      _phoneSize(tester);
      await tester.pumpWidget(_wrap(NutritionDayView(day: day, targets: _targets)));
      await tester.tap(find.text('比例').first);
      await tester.pumpAndSettle();
      // 蛋白 60g×4=240、碳水 100g×4=400、脂肪 30g×9=270 → 共 910
      final pie = tester.widget<PieChart>(find.byType(PieChart));
      expect(pie.data.sections.map((s) => s.value), [240, 400, 270]);
      expect(find.text('910'), findsOneWidget);
      expect(find.text('60 g・240 kcal'), findsOneWidget);
    });
  });

  group('NutritionDayView', () {
    final day = DayNutrition(
      date: DateTime(2026, 10, 7),
      calories: 2300,
      caloriesByMeal: const {'早餐': 500, '午餐': 900, '晚餐': 900},
      nutrients: const Nutrients(protein: 120, carbs: 250, fat: 70, fiber: 18, sodium: 3100),
      entryCount: 6,
    );

    testWidgets('顯示各營養素對目標的數字與熱量佔比', (tester) async {
      _phoneSize(tester);
      await tester.pumpWidget(_wrap(NutritionDayView(day: day, targets: _targets)));
      expect(find.text('2300'), findsOneWidget); // 甜甜圈中間的總熱量
      expect(find.text('120 / 140 g'), findsOneWidget);
      expect(find.text('250 / 220 g'), findsOneWidget);
      expect(find.text('18 / 25 g'), findsOneWidget);
      expect(find.text('3100 / 2400 mg（上限）'), findsOneWidget);
      // 120×4=480、250×4=1000、70×9=630 → 23% / 47% / 30%
      expect(find.text('佔熱量 23%'), findsOneWidget);
    });

    testWidgets('熱量超過目標、鈉超過上限：有警示圖示與文字（不只靠顏色）', (tester) async {
      _phoneSize(tester);
      await tester.pumpWidget(_wrap(NutritionDayView(day: day, targets: _targets)));
      expect(find.text('超過目標 '), findsOneWidget); // 熱量
      expect(find.text('超過上限 '), findsOneWidget); // 鈉
      expect(find.byIcon(Icons.warning_amber_rounded), findsNWidgets(2));
    });

    testWidgets('沒有個人資料（targets = null）：只顯示數字、纖維與鈉仍有參考量', (tester) async {
      _phoneSize(tester);
      await tester.pumpWidget(_wrap(NutritionDayView(day: day)));
      expect(find.text('120 g'), findsOneWidget);
      expect(find.text('2300 kcal'), findsOneWidget);
      expect(find.text('18 / 25 g'), findsOneWidget);
    });
  });

  group('NutritionWeekView', () {
    final dates = datesForRange(StatsRange.week, DateTime(2026, 10, 7));
    final days = groupByDay(dates, [
      {'date': '2026-10-5', 'meal_title': '午餐', 'calories': 1800, 'protein': 100.0},
      {'date': '2026-10-7', 'meal_title': '晚餐', 'calories': 2200, 'protein': 140.0},
    ]);

    testWidgets('長條圖 7 根、目標虛線、平均只算有紀錄的 2 天', (tester) async {
      _phoneSize(tester);
      await tester.pumpWidget(_wrap(
          NutritionWeekView(days: days, today: DateTime(2026, 10, 7), targets: _targets)));

      final chart = tester.widget<BarChart>(find.byType(BarChart));
      expect(chart.data.barGroups.length, 7);
      expect(chart.data.barGroups.map((g) => g.barRods.single.toY),
          [1800, 0, 2200, 0, 0, 0, 0]);
      expect(chart.data.extraLinesData.horizontalLines.single.y, 2000);
      expect(find.text('每日平均（7 天中有 2 天有紀錄）'), findsOneWidget);
      expect(find.text('2000 / 2000 kcal'), findsOneWidget); // (1800+2200)/2
    });

    testWidgets('切換成「蛋白質」：長條與目標線都換成蛋白質', (tester) async {
      _phoneSize(tester);
      await tester.pumpWidget(_wrap(
          NutritionWeekView(days: days, today: DateTime(2026, 10, 7), targets: _targets)));

      await tester.tap(find.text('蛋白質').first);
      await tester.pumpAndSettle();
      expect(find.text('每日蛋白質（g）'), findsOneWidget);
      final chart = tester.widget<BarChart>(find.byType(BarChart));
      expect(chart.data.barGroups[2].barRods.single.toY, 140);
      expect(chart.data.extraLinesData.horizontalLines.single.y, 140);
    });

    testWidgets('每日明細表：沒紀錄的日子顯示「–」，今天標「今天」', (tester) async {
      _phoneSize(tester);
      await tester.pumpWidget(_wrap(
          NutritionWeekView(days: days, today: DateTime(2026, 10, 7), targets: _targets)));
      expect(find.text('今天（三）'), findsOneWidget);
      expect(find.text('1800'), findsOneWidget);
      expect(find.text('–'), findsNWidgets(5 * 4)); // 5 天沒紀錄 × 4 欄
    });
  });

  test('niceMaxY：留空間並對齊好讀的刻度', () {
    expect(niceMaxY(0), 100);
    expect(niceMaxY(2000), 2500);
    expect(niceMaxY(140), 175);
  });
}
