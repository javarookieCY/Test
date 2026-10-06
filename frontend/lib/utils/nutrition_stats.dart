import '../models/nutrients.dart';

// ── 統計頁的純計算邏輯 ──────────────────────────────
// 不依賴 Flutter / DB：輸入 meal_foods 的資料列，輸出每天 / 一段期間的加總與平均，方便單獨寫測試。

/// 統計頁看的是「某一天」還是「一週」
enum StatsRange { day, week }

/// 每日參考量（成人）：
/// 膳食纖維 25 g——國健署建議每日 25–35 g，取下限當目標；
/// 鈉 2400 mg——國健署建議每日鈉攝取不超過 2400 mg（約 6 g 鹽），是「上限」不是目標。
const kFiberTargetG = 25;
const kSodiumLimitMg = 2400;

String dateKey(DateTime d) => '${d.year}-${d.month}-${d.day}';

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// 某個範圍要看哪些日期（由舊到新）。
/// 某一天 = [day]（沒給就是今天）；一週 = [day] 那週的週一到週日（還沒到的日子就是 0）。
/// 用 DateTime(y, m, d ± n) 推日期，不用 Duration，避免跨日光節約時間差一小時。
List<DateTime> datesForRange(StatsRange range, DateTime now, {DateTime? day}) {
  final base = day ?? now;
  DateTime offset(int n) => DateTime(base.year, base.month, base.day + n);
  return switch (range) {
    StatsRange.day => [offset(0)],
    StatsRange.week => [for (int i = 0; i < 7; i++) offset(-(base.weekday - 1) + i)],
  };
}

/// 日期選單列出的日子：今天往前共 [count] 天（新到舊）
List<DateTime> recentDays(DateTime now, {int count = 7}) =>
    [for (int i = 0; i < count; i++) DateTime(now.year, now.month, now.day - i)];

/// 一天的飲食加總
class DayNutrition {
  const DayNutrition({
    required this.date,
    this.calories = 0,
    this.nutrients = Nutrients.zero,
    this.caloriesByMeal = const {},
    this.nutrientsByMeal = const {},
    this.entryCount = 0,
  });

  final DateTime date;
  final int calories;
  final Nutrients nutrients;
  final Map<String, int> caloriesByMeal; // key = 餐別（早餐、午餐…）
  final Map<String, Nutrients> nutrientsByMeal; // 各餐的營養素（圓餅圖切換營養素時用）
  final int entryCount; // 這天記了幾樣食物

  bool get hasData => entryCount > 0;

  /// 把同一天的 meal_foods 資料列加總
  factory DayNutrition.fromRows(DateTime date, Iterable<Map<String, Object?>> rows) {
    var calories = 0;
    var nutrients = Nutrients.zero;
    final byMeal = <String, int>{};
    final nutrientsByMeal = <String, Nutrients>{};
    var count = 0;
    for (final row in rows) {
      final kcal = (row['calories'] as num).toInt();
      calories += kcal;
      final n = Nutrients.fromMap(row);
      nutrients += n;
      final meal = row['meal_title'] as String;
      byMeal[meal] = (byMeal[meal] ?? 0) + kcal;
      nutrientsByMeal[meal] = (nutrientsByMeal[meal] ?? Nutrients.zero) + n;
      count++;
    }
    return DayNutrition(
      date: date,
      calories: calories,
      nutrients: nutrients,
      caloriesByMeal: byMeal,
      nutrientsByMeal: nutrientsByMeal,
      entryCount: count,
    );
  }
}

/// 把多天的 meal_foods 資料列依日期分組加總；沒有紀錄的日子也會有一筆（全部是 0），
/// 順序跟 [dates] 一樣。
List<DayNutrition> groupByDay(List<DateTime> dates, Iterable<Map<String, Object?>> rows) {
  final byKey = <String, List<Map<String, Object?>>>{};
  for (final row in rows) {
    byKey.putIfAbsent(row['date'] as String, () => []).add(row);
  }
  return [for (final d in dates) DayNutrition.fromRows(d, byKey[dateKey(d)] ?? const [])];
}

/// 一段期間的每日平均。只算「有記錄的日子」——沒記的那天不算 0 卡，不會把平均拉低。
class PeriodAverage {
  const PeriodAverage({
    required this.loggedDays,
    required this.calories,
    required this.nutrients,
  });

  final int loggedDays;
  final int calories;
  final Nutrients nutrients;

  factory PeriodAverage.of(List<DayNutrition> days) {
    final logged = days.where((d) => d.hasData).toList();
    if (logged.isEmpty) {
      return const PeriodAverage(loggedDays: 0, calories: 0, nutrients: Nutrients.zero);
    }
    final total = logged.fold(Nutrients.zero, (sum, d) => sum + d.nutrients);
    final kcal = logged.fold(0, (sum, d) => sum + d.calories);
    return PeriodAverage(
      loggedDays: logged.length,
      calories: (kcal / logged.length).round(),
      nutrients: total.scale(1 / logged.length),
    );
  }
}

/// 三大營養素各自提供的熱量佔比（蛋白質, 碳水, 脂肪），以 4/4/9 kcal/g 換算。
/// 用三者熱量的合計當分母（不是記錄的總熱量），三個百分比加起來約 100。
(int protein, int carbs, int fat) macroCaloriePercent(Nutrients n) {
  final p = n.protein * 4, c = n.carbs * 4, f = n.fat * 9;
  final total = p + c + f;
  if (total <= 0) return (0, 0, 0);
  int pct(double v) => (v / total * 100).round();
  return (pct(p), pct(c), pct(f));
}
