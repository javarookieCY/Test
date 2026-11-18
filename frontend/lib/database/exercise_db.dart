import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../models/exercise_entry.dart';
import '../models/exercise_task.dart';
import 'database_service.dart';

/// 運動相關的兩張表：exercises(運動紀錄)、exercise_tasks(訓練清單)
extension ExerciseDb on DatabaseService {
  // ---------- exercises：運動紀錄 ----------

  /// 新增一筆運動紀錄，回傳新的 id
  Future<int> insertExercise(ExerciseEntry entry) async {
    final Database db = await getDatabase;
    final Map<String, dynamic> values = entry.toMap();
    final int id = await db.insert('exercises', values);
    return id;
  }

  /// 某一天的所有運動紀錄，新的在前面
  Future<List<ExerciseEntry>> getExercisesByDate(String date) async {
    final Database db = await getDatabase;
    final List<Map<String, Object?>> rows = await db.query(
      'exercises',
      where: 'date = ?',
      whereArgs: [date],
      orderBy: 'id DESC',
    );

    final List<ExerciseEntry> entries = <ExerciseEntry>[];
    for (final Map<String, Object?> row in rows) {
      final ExerciseEntry entry = ExerciseEntry.fromMap(row);
      entries.add(entry);
    }
    return entries;
  }

  /// 刪除一筆運動紀錄，回傳刪掉幾筆
  Future<int> deleteExercise(int id) async {
    final Database db = await getDatabase;
    final int deletedCount = await db.delete(
      'exercises',
      where: 'id = ?',
      whereArgs: [id],
    );
    return deletedCount;
  }

  /// 某一天運動消耗的總熱量（給首頁「剩餘熱量」加回去）。
  Future<int> getBurnedCaloriesByDate(String date) async {
    final Database db = await getDatabase;

    // SUM 加總；那天沒資料時 SUM 是 null，COALESCE 把 null 換成 0
    final List<Map<String, Object?>> rows = await db.rawQuery(
      'SELECT COALESCE(SUM(calories), 0) AS c FROM exercises WHERE date = ?',
      [date],
    );

    final Map<String, Object?> firstRow = rows.first;
    final Object? total = firstRow['c'];
    if (total == null) {
      return 0;
    }
    return total as int;
  }

  // ---------- exercise_tasks：今日訓練清單 ----------

  /// 新增一個訓練清單的動作，回傳新的 id
  Future<int> insertExerciseTask(ExerciseTask task) async {
    final Database db = await getDatabase;
    final Map<String, dynamic> values = task.toMap();
    final int id = await db.insert('exercise_tasks', values);
    return id;
  }

  /// 某一天的訓練清單，依「重訓 → 有氧 → 伸展」排序，同分類內依新增順序排列。
  Future<List<ExerciseTask>> getExerciseTasksByDate(String date) async {
    final Database db = await getDatabase;
    final List<Map<String, Object?>> rows = await db.query(
      'exercise_tasks',
      where: 'date = ?',
      whereArgs: [date],
      orderBy: "CASE category WHEN 'cardio' THEN 1 WHEN 'flexibility' THEN 2 ELSE 0 END, id ASC",
    );

    final List<ExerciseTask> tasks = <ExerciseTask>[];
    for (final Map<String, Object?> row in rows) {
      final ExerciseTask task = ExerciseTask.fromMap(row);
      tasks.add(task);
    }
    return tasks;
  }

  /// 打勾 / 取消打勾，回傳改了幾筆
  Future<int> setExerciseTaskDone(int id, bool done) async {
    final Database db = await getDatabase;

    // 資料庫沒有 bool，用 1 代表打勾、0 代表沒打勾
    int doneValue;
    if (done) {
      doneValue = 1;
    } else {
      doneValue = 0;
    }

    final Map<String, Object?> values = <String, Object?>{
      'done': doneValue,
    };
    final int updatedCount = await db.update(
      'exercise_tasks',
      values,
      where: 'id = ?',
      whereArgs: [id],
    );
    return updatedCount;
  }

  /// 刪除一個訓練清單的動作，回傳刪掉幾筆
  Future<int> deleteExerciseTask(int id) async {
    final Database db = await getDatabase;
    final int deletedCount = await db.delete(
      'exercise_tasks',
      where: 'id = ?',
      whereArgs: [id],
    );
    return deletedCount;
  }

  /// 修改清單裡某個動作的組數（重訓）或分鐘數（有氧 / 伸展），回傳改了幾筆。
  Future<int> updateExerciseTaskAmount(int id, {int? sets, int? minutes}) async {
    final Database db = await getDatabase;
    final Map<String, Object?> values = <String, Object?>{
      'sets': sets,
      'minutes': minutes,
    };
    final int updatedCount = await db.update(
      'exercise_tasks',
      values,
      where: 'id = ?',
      whereArgs: [id],
    );
    return updatedCount;
  }

  /// 把自動產生的運動計畫寫進 exercise_tasks。
  /// tasksByDate 的 key 是日期 (yyyy-M-d)，value 是那天要做的動作。
  /// 已經有打勾任務的那天整天跳過，其餘日期先清空再寫入，避免跟舊清單重複。
  Future<void> applyWeeklyPlan(Map<String, List<ExerciseTask>> tasksByDate) async {
    final Database db = await getDatabase;

    // transaction：裡面的操作要嘛全部成功，要嘛全部不做
    // 在 transaction 裡要用 txn 操作，不能用 db
    await db.transaction((Transaction txn) async {
      for (final MapEntry<String, List<ExerciseTask>> entry in tasksByDate.entries) {
        final String date = entry.key;
        final List<ExerciseTask> tasksOfDay = entry.value;

        // 這天有沒有已經打勾的動作
        final List<Map<String, Object?>> doneRows = await txn.query(
          'exercise_tasks',
          where: 'date = ? AND done = 1',
          whereArgs: [date],
          limit: 1,
        );

        // 有打勾的：整天不動，跳到下一天
        if (doneRows.isNotEmpty) {
          continue;
        }

        // 沒打勾的：先清空這天，再寫入新的計畫
        await txn.delete(
          'exercise_tasks',
          where: 'date = ?',
          whereArgs: [date],
        );

        for (final ExerciseTask task in tasksOfDay) {
          final Map<String, dynamic> values = task.toMap();
          await txn.insert('exercise_tasks', values);
        }
      }
    });
  }
}
