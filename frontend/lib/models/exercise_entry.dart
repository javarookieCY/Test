/// 一筆運動紀錄。對應 SQLite 的 exercises 表
/// (id / date / name / minutes / calories)。
class ExerciseEntry {
  // 建構子：大括號 {} 裡是具名參數，呼叫時要寫名字，例如 ExerciseEntry(date: ..., name: ...)
  // required = 必填；沒有 required 的(id)可以不填，不填就是 null
  ExerciseEntry({
    this.id,
    required this.date,
    required this.name,
    required this.minutes,
    required this.calories,
  });

  final int? id; // 資料庫的主鍵；新增前是 null
  final String date; // yyyy-M-d
  final String name; // 運動類型，例如：跑步、重量訓練
  final int minutes; // 時長（分鐘）
  final int calories; // 消耗熱量 (kcal)

  /// 物件 → Map(存進資料庫用)
  Map<String, dynamic> toMap() {
    final Map<String, dynamic> map = <String, dynamic>{
      'date': date,
      'name': name,
      'minutes': minutes,
      'calories': calories,
    };
    return map;
  }

  /// Map → 物件(從資料庫讀出來用)
  /// factory 建構子：相當於 Java 的 static ExerciseEntry fromMap(Map map) 方法
  factory ExerciseEntry.fromMap(Map<String, dynamic> map) {
    final int? id = map['id'] as int?;
    final String date = map['date'] as String;
    final String name = map['name'] as String;

    // 資料庫的數字可能是整數或小數，先當成 num(兩者都可以)，再轉成 int
    final num minutesNumber = map['minutes'] as num;
    final int minutes = minutesNumber.toInt();
    final num caloriesNumber = map['calories'] as num;
    final int calories = caloriesNumber.toInt();

    return ExerciseEntry(
      id: id,
      date: date,
      name: name,
      minutes: minutes,
      calories: calories,
    );
  }
}
