/// 訓練清單裡的分類：重訓 or 有氧。
enum ExerciseTaskCategory { strength, cardio }

extension ExerciseTaskCategoryX on ExerciseTaskCategory {
  String get dbValue => this == ExerciseTaskCategory.cardio ? 'cardio' : 'strength';
  String get label => this == ExerciseTaskCategory.cardio ? '有氧' : '重訓';

  static ExerciseTaskCategory fromDbValue(String v) =>
      v == 'cardio' ? ExerciseTaskCategory.cardio : ExerciseTaskCategory.strength;
}

/// 一筆「今日訓練清單」的任務。對應 SQLite 的 exercise_tasks 表
/// (id / date / category / name / sets / minutes / done)。
/// 重訓填 sets（組數），有氧填 minutes（分鐘數），兩者只會有一個有值。
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

  /// 給清單顯示用的細節文字，例如「3 組」或「20 分鐘」。
  String get detailLabel {
    if (category == ExerciseTaskCategory.strength) {
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
