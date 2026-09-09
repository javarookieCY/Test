/// 一筆運動紀錄。對應 SQLite 的 exercises 表
/// (id / date / name / minutes / calories)。
class ExerciseEntry {
  ExerciseEntry({
    this.id,
    required this.date,
    required this.name,
    required this.minutes,
    required this.calories,
  });

  final int? id;
  final String date; // yyyy-M-d
  final String name; // 運動類型，例如：跑步、重量訓練
  final int minutes; // 時長（分鐘）
  final int calories; // 消耗熱量 (kcal)

  Map<String, dynamic> toMap() => {
        'date': date,
        'name': name,
        'minutes': minutes,
        'calories': calories,
      };

  factory ExerciseEntry.fromMap(Map<String, dynamic> map) => ExerciseEntry(
        id: map['id'] as int?,
        date: map['date'] as String,
        name: map['name'] as String,
        minutes: (map['minutes'] as num).toInt(),
        calories: (map['calories'] as num).toInt(),
      );
}
