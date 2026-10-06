import 'dart:math' as math;

import '../models/exercise_task.dart';
import 'exercise_catalog.dart';
import 'nutrition_math.dart';

// ── 每週運動計畫的純計算邏輯 ──────────────────────────────
// 跟 nutrition_math.dart 一樣不依賴 Flutter / DB，方便單獨寫測試。
// 流程：基本資料 → 查表決定一週每天練什麼 (DayType) → 依器材/目標/年齡/BMI 挑動作、調整組數與分鐘數。
// 動作一律從 exercise_catalog.dart 的動作庫挑，數量也會被拉回該動作的合理範圍。

/// 一天的訓練類型
enum DayType { fullBody, upper, lower, cardio, rest }

extension DayTypeInfo on DayType {
  String get label => switch (this) {
        DayType.fullBody => '全身訓練',
        DayType.upper => '上肢訓練',
        DayType.lower => '下肢訓練',
        DayType.cardio => '有氧日',
        DayType.rest => '休息 / 恢復',
      };

  /// 一週總覽小圓點底下的兩字簡稱
  String get shortLabel => switch (this) {
        DayType.fullBody => '全身',
        DayType.upper => '上肢',
        DayType.lower => '下肢',
        DayType.cardio => '有氧',
        DayType.rest => '休息',
      };

  bool get isStrength =>
      this == DayType.fullBody || this == DayType.upper || this == DayType.lower;
}

/// 計畫裡的一個動作（還沒綁日期，存 DB 前再用 toTask 轉成 ExerciseTask）
class PlannedExercise {
  const PlannedExercise(this.exercise, this.amount);

  final ExerciseDef exercise;
  final int amount; // 重訓 = 組數；有氧 / 伸展 = 分鐘數

  String get name => exercise.name;
  ExerciseTaskCategory get category => exercise.category;
  int? get sets => category.usesSets ? amount : null;
  int? get minutes => category.usesSets ? null : amount;

  /// 預覽用，例如「高腳杯深蹲 3組」「快走 30分鐘」
  String get summary => '$name $amount${exercise.unit}';

  ExerciseTask toTask(String date) => ExerciseTask(
        date: date,
        category: category,
        name: name,
        sets: sets,
        minutes: minutes,
      );
}

/// 計畫中的一天
class WorkoutDay {
  const WorkoutDay(this.type, this.items);
  final DayType type;
  final List<PlannedExercise> items;

  /// 粗估總時間：重訓日加 5 分鐘暖身、每組約 2 分鐘（含組間休息），
  /// 有氧 / 伸展直接加分鐘數；四捨五入到 5 分鐘。
  int get estimatedMinutes {
    var total = type.isStrength ? 5 : 0;
    for (final e in items) {
      total += e.sets != null ? e.sets! * 2 : e.minutes!;
    }
    return (total / 5).round() * 5;
  }
}

/// 一整週的計畫，加上畫面要解釋「為什麼這樣排」的資訊
class WeeklyPlan {
  const WeeklyPlan({
    required this.goal,
    required this.days,
    required this.bmi,
    required this.repRange,
    required this.holdRange,
    required this.notes,
  });

  final Goal goal;
  final List<WorkoutDay> days; // index 0 = 週一
  final double bmi;
  final String repRange; // 重訓每組次數，例如「12–15 下」
  final String holdRange; // 棒式這類靜態動作每組秒數，例如「30–45 秒」
  final List<String> notes; // 依身體狀況做的調整，一條一句

  int get trainingDays => days.where((d) => d.type != DayType.rest).length;

  /// 某個動作的份量說明，例如「3 組 × 12–15 下」「30 分鐘」
  String doseOf(PlannedExercise e) {
    if (e.sets == null) return '${e.minutes} 分鐘';
    return '${e.sets} 組 × ${e.exercise.timed ? holdRange : repRange}';
  }
}

const _f = DayType.fullBody,
    _u = DayType.upper,
    _l = DayType.lower,
    _c = DayType.cardio;

/// 一週最多可以選幾天運動（至少留一天休息）
const kMaxWorkoutDays = 6;

/// 目標 → 選了幾天 → 這幾天依序練什麼（休息日不在裡面）
const _sequences = <Goal, Map<int, List<DayType>>>{
  Goal.cut: {
    1: [_f],
    2: [_f, _c],
    3: [_f, _c, _f],
    4: [_f, _c, _f, _c],
    5: [_f, _c, _f, _c, _f],
    6: [_f, _c, _f, _c, _f, _c],
  },
  Goal.maintain: {
    1: [_f],
    2: [_f, _f],
    3: [_f, _f, _c],
    4: [_f, _c, _f, _c],
    5: [_u, _l, _c, _f, _c],
    6: [_u, _l, _c, _u, _l, _c],
  },
  Goal.bulk: {
    1: [_f],
    2: [_f, _f],
    3: [_f, _f, _f],
    4: [_u, _l, _u, _l],
    5: [_u, _l, _f, _u, _l],
    6: [_u, _l, _f, _u, _l, _f],
  },
};

/// 只知道「每週幾天」時的預設運動日（1 = 週一 … 7 = 週日），盡量把休息日分散開
Set<int> defaultWorkoutWeekdays(int days) => switch (days.clamp(1, kMaxWorkoutDays)) {
      1 => {1},
      2 => {1, 4},
      3 => {1, 3, 5},
      4 => {1, 2, 4, 5},
      5 => {1, 2, 3, 5, 6},
      _ => {1, 2, 3, 4, 5, 6},
    };

ExerciseDef _ex(String name) => findExercise(name)!;

/// 依基本資料排出一週（index 0 = 週一）的運動計畫。
/// [workoutWeekdays] 是使用者選的運動日（1 = 週一 … 7 = 週日），其他天是休息日。
/// 每個動作位置都有一串候選（大致是 器械 / 槓鈴 → 啞鈴 → 徒手），
/// 挑第一個使用者有器材可以做的；最後一個候選一定是徒手動作，所以不會排不出來。
WeeklyPlan buildWeeklyPlan({
  required Goal goal,
  required Set<int> workoutWeekdays,
  required int age,
  required double weightKg,
  required double heightCm,
  required Set<Equipment> equipment,
}) {
  final chosen = workoutWeekdays.where((d) => d >= 1 && d <= 7).toSet();
  if (chosen.isEmpty) chosen.add(1);
  final sequence = _sequences[goal]![chosen.length.clamp(1, kMaxWorkoutDays)]!;
  var next = 0;
  final pattern = [
    for (int d = 1; d <= 7; d++)
      chosen.contains(d) && next < sequence.length ? sequence[next++] : DayType.rest,
  ];

  final heightM = heightCm / 100;
  final bmi = weightKg / (heightM * heightM);
  final older = age >= 50;
  final heavy = bmi >= 27; // 國健署標準：BMI ≥ 27 屬肥胖
  final underweight = bmi < 18.5;
  final lowImpact = older || heavy; // 用不跑不跳的動作保護膝蓋

  final sets = (goal == Goal.bulk ? 4 : 3) - (older ? 1 : 0);
  final cardio = _ex(lowImpact ? '快走' : '慢跑');
  var cardioMinutes = switch (goal) {
        Goal.cut => 40,
        Goal.maintain => 30,
        Goal.bulk => 20,
      } -
      (older ? 10 : 0);
  if (underweight) cardioMinutes = math.min(cardioMinutes, 20);

  final available = {Equipment.bodyweight, ...equipment};
  ExerciseDef pick(List<String> candidates) =>
      candidates.map(_ex).firstWhere((e) => hasEquipmentFor(e, available));

  // 槓鈴臥推要有槓鈴（通常也就有臥推椅）；在家只有啞鈴多半沒有臥推椅，就做伏地挺身
  final push = pick(['槓鈴臥推', heavy ? '跪姿伏地挺身' : '伏地挺身']);
  final pull = pick(['滑輪下拉', '啞鈴划船', '槓鈴划船', '超人式']);
  final shoulder = pick(['啞鈴肩推', '槓鈴肩推', '派克伏地挺身']);
  final arms = pick(['啞鈴二頭彎舉', '三頭肌下壓', '椅子撐體']);
  // 低衝擊（50 歲以上或 BMI 偏高）：腿推坐著做、不用顧平衡；硬舉類取代弓箭步
  final squat = pick(lowImpact ? ['腿推', '徒手深蹲'] : ['槓鈴深蹲', '高腳杯深蹲', '徒手深蹲']);
  final hinge = pick(lowImpact ? ['啞鈴羅馬尼亞硬舉', '腿彎舉', '鳥狗式'] : ['弓箭步']);
  final glute = pick(lowImpact ? ['臀橋'] : ['槓鈴臀推', '臀橋']);

  PlannedExercise s(ExerciseDef e) => PlannedExercise(e, e.clampAmount(sets));
  PlannedExercise m(ExerciseDef e, int minutes) =>
      PlannedExercise(e, e.clampAmount(minutes));

  List<PlannedExercise> itemsFor(DayType type) {
    final items = switch (type) {
      DayType.fullBody => [s(squat), s(push), s(pull), s(_ex('棒式'))],
      DayType.upper => [s(push), s(shoulder), s(pull), s(arms)],
      DayType.lower => [s(squat), s(hinge), s(glute), s(_ex('提踵'))],
      DayType.cardio => [m(cardio, cardioMinutes)],
      DayType.rest => [m(_ex('靜態伸展'), 10)],
    };
    // 減脂：重訓日最後再補 15 分鐘有氧（體重過輕就不補）
    if (goal == Goal.cut && type.isStrength && !underweight) {
      items.add(m(cardio, 15));
    }
    return items;
  }

  final bmiText = bmi.toStringAsFixed(1);
  final equipmentText = [
    for (final e in Equipment.values)
      if (available.contains(e)) e.label
  ].join('、');
  final notes = <String>[
    '器材：$equipmentText，動作都用這些器材安排',
    if (heavy)
      'BMI $bmiText 偏高：有氧改快走、避開跑跳，上下肢都改用對膝蓋與關節較溫和的動作'
    else if (underweight)
      'BMI $bmiText 偏低：以重訓為主，有氧縮短到 20 分鐘以內，記得吃夠熱量'
    else
      'BMI $bmiText 在標準範圍，照一般強度安排',
    if (older) '50 歲以上：每個動作少 1 組、有氧少 10 分鐘，並改用不跑不跳的低衝擊動作',
  ];

  return WeeklyPlan(
    goal: goal,
    days: [for (final type in pattern) WorkoutDay(type, itemsFor(type))],
    bmi: bmi,
    repRange: switch (goal) {
      Goal.cut => '12–15 下',
      Goal.maintain => '10–12 下',
      Goal.bulk => '8–12 下',
    },
    holdRange: older ? '20–30 秒' : '30–45 秒',
    notes: notes,
  );
}

/// 把計畫攤到「本週從今天到週日」的實際日期上（今天以前的日子不動）。
/// 回傳的 key 是日期字串 (yyyy-M-d)，可以直接丟給 DBHelper.applyWeeklyPlan。
Map<String, List<ExerciseTask>> planToTasks(WeeklyPlan plan, DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  final result = <String, List<ExerciseTask>>{};
  for (int i = today.weekday - 1; i < 7; i++) {
    final d = DateTime(today.year, today.month, today.day - (today.weekday - 1) + i);
    final date = '${d.year}-${d.month}-${d.day}';
    result[date] = plan.days[i].items.map((e) => e.toTask(date)).toList();
  }
  return result;
}
