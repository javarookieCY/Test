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
  /// 存進資料庫的字串
  String get dbValue {
    switch (this) {
      case ExerciseTaskCategory.strength:
        return 'strength';
      case ExerciseTaskCategory.cardio:
        return 'cardio';
      case ExerciseTaskCategory.flexibility:
        return 'flexibility';
    }
  }

  /// 畫面上顯示的文字
  String get label {
    switch (this) {
      case ExerciseTaskCategory.strength:
        return '重訓';
      case ExerciseTaskCategory.cardio:
        return '有氧';
      case ExerciseTaskCategory.flexibility:
        return '伸展';
    }
  }

  /// 重訓記「組數」；有氧、伸展記「分鐘數」
  bool get usesSets {
    if (this == ExerciseTaskCategory.strength) {
      return true;
    }
    return false;
  }

  /// 資料庫的字串 → enum；不認得的字串一律當重訓
  static ExerciseTaskCategory fromDbValue(String value) {
    switch (value) {
      case 'cardio':
        return ExerciseTaskCategory.cardio;
      case 'flexibility':
        return ExerciseTaskCategory.flexibility;
      default:
        return ExerciseTaskCategory.strength;
    }
  }
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
    this.done = false, // 不填就是 false
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
      if (sets == null) {
        return '';
      }
      return '$sets 組';
    }

    if (minutes == null) {
      return '';
    }
    return '$minutes 分鐘';
  }

  /// 物件 → Map(存進資料庫用)
  Map<String, dynamic> toMap() {
    // 資料庫沒有 bool，用 1 代表打勾、0 代表沒打勾
    int doneValue;
    if (done) {
      doneValue = 1;
    } else {
      doneValue = 0;
    }

    final Map<String, dynamic> map = <String, dynamic>{
      'date': date,
      'category': category.dbValue,
      'name': name,
      'sets': sets,
      'minutes': minutes,
      'done': doneValue,
    };
    return map;
  }

  /// Map → 物件(從資料庫讀出來用)
  factory ExerciseTask.fromMap(Map<String, dynamic> map) {
    final int? id = map['id'] as int?;
    final String date = map['date'] as String;
    final String categoryText = map['category'] as String;
    final ExerciseTaskCategory category = ExerciseTaskCategoryX.fromDbValue(categoryText);
    final String name = map['name'] as String;

    // sets、minutes 可能是 null(兩者只會有一個有值)
    int? sets;
    final Object? setsValue = map['sets'];
    if (setsValue != null) {
      final num setsNumber = setsValue as num;
      sets = setsNumber.toInt();
    }

    int? minutes;
    final Object? minutesValue = map['minutes'];
    if (minutesValue != null) {
      final num minutesNumber = minutesValue as num;
      minutes = minutesNumber.toInt();
    }

    final num doneNumber = map['done'] as num;
    bool done;
    if (doneNumber.toInt() == 1) {
      done = true;
    } else {
      done = false;
    }

    return ExerciseTask(
      id: id,
      date: date,
      category: category,
      name: name,
      sets: sets,
      minutes: minutes,
      done: done,
    );
  }
}
