/// 訓練清單裡的分類：重訓（算組數）、有氧 / 伸展（算分鐘數）。
enum ExerciseTaskCategory { strength, cardio, flexibility }

/*
  幫ExerciseTaskCategory這個不能extends的固定型別 加上"ExerciseTaskCategoryX"這個方法
  方法內容:
    1. get dbValue, get label, get usesSets
    自動得知使用者選擇的是重訓、有氧還是伸展
    enum轉String
    label代表螢幕顯示的文字
    dbValue代表db存的字串
    usesSets代表這個分類記「組數」（重訓）還是「分鐘數」（有氧、伸展）

    2. fromDbValue(String v)
    String轉enum
    傳入db的字串看是ExerciseTaskCategory的哪個型別
*/
extension ExerciseTaskCategoryX on ExerciseTaskCategory {
  String get dbValue => switch (this) {
        ExerciseTaskCategory.strength => 'strength',
        ExerciseTaskCategory.cardio => 'cardio',
        ExerciseTaskCategory.flexibility => 'flexibility',
      };

  String get label => switch (this) {
        ExerciseTaskCategory.strength => '重訓',
        ExerciseTaskCategory.cardio => '有氧',
        ExerciseTaskCategory.flexibility => '伸展',
      };

  bool get usesSets => this == ExerciseTaskCategory.strength;

  static ExerciseTaskCategory fromDbValue(String v) => switch (v) {
        'cardio' => ExerciseTaskCategory.cardio,
        'flexibility' => ExerciseTaskCategory.flexibility,
        _ => ExerciseTaskCategory.strength,
      };
}

/// 一筆「今日訓練清單」的任務。對應 SQLite 的 exercise_tasks 表
/// (id / date / category / name / sets / minutes / done)。
/// 重訓填 sets（組數），有氧 / 伸展填 minutes（分鐘數），兩者只會有一個有值。
class ExerciseTask {
  ExerciseTask({
    this.id,
    required this.date,
    required this.category,
    required this.name,
    this.sets,
    this.minutes,
    this.done = false,
  });

  final int? id;
  final String date; // yyyy-M-d
  final ExerciseTaskCategory category;
  final String name; // 想做的動作，例如：深蹲、跑步
  final int? sets; // 重訓：組數
  final int? minutes; // 有氧：分鐘數
  final bool done;

  /*
    根據這個任務的enum型別來決定要顯示"組"還是"分鐘"
  */
  String get detailLabel {
    if (category.usesSets) {
      return sets != null ? '$sets 組' : '';
    }
    return minutes != null ? '$minutes 分鐘' : '';
  }

  Map<String, dynamic> toMap() => {
        'date': date,
        'category': category.dbValue,
        'name': name,
        'sets': sets,
        'minutes': minutes,
        'done': done ? 1 : 0,
      };

  factory ExerciseTask.fromMap(Map<String, dynamic> map) => ExerciseTask(
        id: map['id'] as int?,
        date: map['date'] as String,
        category: ExerciseTaskCategoryX.fromDbValue(map['category'] as String),
        name: map['name'] as String,
        sets: (map['sets'] as num?)?.toInt(),
        minutes: (map['minutes'] as num?)?.toInt(),
        done: (map['done'] as num).toInt() == 1,
      );
}
