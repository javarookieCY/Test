import '../utils/nutrition_math.dart';

/// 使用者個人資料（DB 只存一列，id 固定為 1）。
/// Onboarding 時建立，之後可在設定頁修改。
class UserProfile {
  UserProfile({
    required this.heightCm,
    required this.weightKg,
    required this.age,
    required this.sex,
    required this.activity,
    required this.goal,
  });

  final double heightCm;
  final double weightKg; // 最近一次體重（也會寫進 weight_log）
  final int age;
  final Sex sex;
  final ActivityLevel activity;
  final Goal goal;

  /// 依目前資料算出的每日熱量與三大營養素目標
  NutritionTargets get targets => computeTargets(
        sex: sex,
        weightKg: weightKg,
        heightCm: heightCm,
        age: age,
        activity: activity,
        goal: goal,
      );

  UserProfile copyWith({
    double? heightCm,
    double? weightKg,
    int? age,
    Sex? sex,
    ActivityLevel? activity,
    Goal? goal,
  }) {
    return UserProfile(
      heightCm: heightCm ?? this.heightCm,
      weightKg: weightKg ?? this.weightKg,
      age: age ?? this.age,
      sex: sex ?? this.sex,
      activity: activity ?? this.activity,
      goal: goal ?? this.goal,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': 1,
        'height_cm': heightCm,
        'weight_kg': weightKg,
        'age': age,
        'sex': sex.name,
        'activity_level': activity.name,
        'goal': goal.name,
      };

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    return UserProfile(
      heightCm: (map['height_cm'] as num).toDouble(),
      weightKg: (map['weight_kg'] as num).toDouble(),
      age: (map['age'] as num).toInt(),
      sex: Sex.values.byName(map['sex'] as String),
      activity: ActivityLevel.values.byName(map['activity_level'] as String),
      goal: Goal.values.byName(map['goal'] as String),
    );
  }
}

/// 一筆體重紀錄
class WeightEntry {
  WeightEntry({required this.date, required this.weightKg});

  final String date; // yyyy-M-d
  final double weightKg;

  factory WeightEntry.fromMap(Map<String, dynamic> map) => WeightEntry(
        date: map['date'] as String,
        weightKg: (map['weight_kg'] as num).toDouble(),
      );
}
