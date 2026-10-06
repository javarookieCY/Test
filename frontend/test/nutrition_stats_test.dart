import 'package:flutter_application_1/models/food_item.dart';
import 'package:flutter_application_1/models/nutrients.dart';
import 'package:flutter_application_1/utils/nutrition_stats.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, Object?> row(String date, String meal, int kcal,
        {double p = 0, double c = 0, double f = 0, double fiber = 0, double na = 0}) =>
    {
      'date': date,
      'meal_title': meal,
      'food_name': 'x',
      'calories': kcal,
      'portion': 1.0,
      'protein': p,
      'carbs': c,
      'fat': f,
      'fiber': fiber,
      'sodium': na,
    };

void main() {
  group('datesForRange / recentDays', () {
    final now = DateTime(2026, 10, 7, 21, 30); // 週三晚上

    test('某一天：沒指定就是今天；指定的那天去掉時分', () {
      expect(datesForRange(StatsRange.day, now), [DateTime(2026, 10, 7)]);
      expect(datesForRange(StatsRange.day, now, day: DateTime(2026, 9, 1, 13)),
          [DateTime(2026, 9, 1)]);
    });

    test('一週 = 本週一到週日，由舊到新（包含還沒到的日子）', () {
      final week = datesForRange(StatsRange.week, now);
      expect(week.length, 7);
      expect(week.first, DateTime(2026, 10, 5)); // 週一
      expect(week.last, DateTime(2026, 10, 11)); // 週日
      expect(week.map((d) => d.weekday), [1, 2, 3, 4, 5, 6, 7]);
    });

    test('週一、週日當天也落在同一週', () {
      expect(datesForRange(StatsRange.week, DateTime(2026, 10, 5)).first, DateTime(2026, 10, 5));
      expect(datesForRange(StatsRange.week, DateTime(2026, 10, 11, 23, 59)).first,
          DateTime(2026, 10, 5));
    });

    test('跨月、跨年都正確', () {
      // 2026-3-1 是週日 → 這週從 2/23 開始
      final week = datesForRange(StatsRange.week, DateTime(2026, 3, 1));
      expect(week.first, DateTime(2026, 2, 23));
      expect(week.last, DateTime(2026, 3, 1));
      expect(recentDays(DateTime(2027, 1, 2)).last, DateTime(2026, 12, 27));
    });

    test('日期清單：今天往前 7 天，新到舊', () {
      final days = recentDays(now);
      expect(days.length, 7);
      expect(days.first, DateTime(2026, 10, 7));
      expect(days.last, DateTime(2026, 10, 1));
    });
  });

  group('DayNutrition / groupByDay', () {
    test('同一天的紀錄加總：熱量、各餐熱量、五種營養素', () {
      final day = DayNutrition.fromRows(DateTime(2026, 10, 7), [
        row('2026-10-7', '早餐', 300, p: 20, c: 30, f: 10, fiber: 2, na: 400),
        row('2026-10-7', '早餐', 100, p: 5),
        row('2026-10-7', '晚餐', 600, p: 40, c: 60, f: 20, fiber: 5, na: 900),
      ]);
      expect(day.calories, 1000);
      expect(day.caloriesByMeal, {'早餐': 400, '晚餐': 600});
      expect(day.nutrientsByMeal['早餐']!.protein, 25); // 20 + 5
      expect(day.nutrientsByMeal['晚餐']!.sodium, 900);
      expect(day.nutrients.protein, 65);
      expect(day.nutrients.sodium, 1300);
      expect(day.entryCount, 3);
      expect(day.hasData, isTrue);
    });

    test('依日期分組；沒紀錄的日子也有一筆 0，順序跟 dates 一樣', () {
      final dates = [DateTime(2026, 10, 5), DateTime(2026, 10, 6), DateTime(2026, 10, 7)];
      final days = groupByDay(dates, [
        row('2026-10-7', '午餐', 700),
        row('2026-10-5', '午餐', 500),
        row('2026-9-30', '午餐', 999), // 範圍外的資料不會混進來
      ]);
      expect(days.map((d) => d.calories), [500, 0, 700]);
      expect(days[1].hasData, isFalse);
    });

    test('舊資料沒有營養素欄位時當 0', () {
      final day = DayNutrition.fromRows(DateTime(2026, 10, 7), [
        {'date': '2026-10-7', 'meal_title': '午餐', 'calories': 500},
      ]);
      expect(day.calories, 500);
      expect(day.nutrients.protein, 0);
    });
  });

  group('PeriodAverage', () {
    test('只平均有紀錄的日子', () {
      final days = groupByDay(
        [DateTime(2026, 10, 5), DateTime(2026, 10, 6), DateTime(2026, 10, 7)],
        [row('2026-10-5', '午餐', 2000, p: 100), row('2026-10-7', '午餐', 1600, p: 80)],
      );
      final avg = PeriodAverage.of(days);
      expect(avg.loggedDays, 2);
      expect(avg.calories, 1800);
      expect(avg.nutrients.protein, 90);
    });

    test('全部沒紀錄：平均 0、0 天', () {
      final avg = PeriodAverage.of([DayNutrition(date: DateTime(2026, 10, 7))]);
      expect(avg.loggedDays, 0);
      expect(avg.calories, 0);
    });
  });

  test('macroCaloriePercent：以 4/4/9 換算，加總約 100', () {
    // 蛋白 100g=400、碳水 200g=800、脂肪 ~88.9g=800 → 20/40/40
    final (p, c, f) = macroCaloriePercent(const Nutrients(protein: 100, carbs: 200, fat: 800 / 9));
    expect((p, c, f), (20, 40, 40));
    expect(macroCaloriePercent(Nutrients.zero), (0, 0, 0));
  });

  group('Nutrients', () {
    test('加總與乘上份數', () {
      const a = Nutrients(protein: 10, carbs: 20, fat: 5, fiber: 2, sodium: 100);
      final b = (a + a).scale(1.5);
      expect(b.protein, 30);
      expect(b.sodium, 300);
    });

    test('FoodItem 的營養素 × 份數；toMap/fromMap 保留纖維與鈉', () {
      final food = FoodItem(
          id: 1, name: '地瓜', calories: 86, protein: 1.6, carbs: 20, fat: 0.1, fiber: 3, sodium: 55);
      expect(food.nutrients.scale(2).fiber, 6);
      final restored = FoodItem.fromMap({'id': 1, ...food.toMap()});
      expect(restored.fiber, 3);
      expect(restored.sodium, 55);
    });

    test('舊版 foods 資料列沒有纖維 / 鈉欄位也讀得出來', () {
      final food = FoodItem.fromMap(
          {'id': 1, 'name': '蛋', 'calories': 70, 'protein': 6, 'carbs': 0, 'fat': 5});
      expect(food.fiber, 0);
      expect(food.sodium, 0);
    });
  });
}
