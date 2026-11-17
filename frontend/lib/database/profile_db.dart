import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../user/user_profile.dart';
import 'database_service.dart';

/// 個人資料相關的兩張表：user_profile(只有一筆，id = 1)、weight_log(體重紀錄)
/// 這個檔案刻意不用任何簡寫，每個變數都寫出型別。
extension ProfileDb on DatabaseService {
  // ---------- user_profile：個人化目標 ----------

  /// 讀出個人資料；還沒填過的話回傳 null
  Future<UserProfile?> getUserProfile() async {
    // getDatabase 是 DatabaseService 的 getter，回傳 Future<Database>
    // await 之後拿到 Database
    final Database db = await getDatabase;

    // db.query 回傳 Future<List<Map<String, Object?>>>
    // await 之後拿到 List<Map<String, Object?>>：一個清單，裡面每個 Map 是一列資料
    final List<Map<String, Object?>> rows = await db.query(
      'user_profile',
      where: 'id = 1',
      limit: 1,
    );

    // 查不到資料(還沒填過個人資料)：回傳 null
    if (rows.isEmpty) {
      return null;
    }

    // 查得到：取第一列，轉成 UserProfile 物件
    final Map<String, Object?> firstRow = rows.first;
    final UserProfile profile = UserProfile.fromMap(firstRow);
    return profile;
  }

  /// 存個人資料（id 固定是 1，已經有就覆蓋），同時把當天體重寫進 weight_log。
  Future<void> saveUserProfile(UserProfile profile) async {
    final Database db = await getDatabase;

    // 物件 → Map，資料庫只看得懂 Map
    final Map<String, dynamic> profileMap = profile.toMap();

    await db.insert(
      'user_profile',
      profileMap,
      conflictAlgorithm: ConflictAlgorithm.replace, // 主鍵重複就覆蓋舊的那筆
    );

    final String today = _todayStr();
    await logWeight(today, profile.weightKg);
  }

  /// 只改每週運動日（本週計畫頁點圓圈時用），不像 saveUserProfile 會順便記一筆體重。
  Future<void> updateWorkoutWeekdays(Set<int> weekdays) async {
    final Database db = await getDatabase;

    // Set 沒有順序，先轉成 List 才能排序，例如 {5, 1, 3} → [1, 3, 5]
    final List<int> sortedWeekdays = weekdays.toList();
    sortedWeekdays.sort();

    // [1, 3, 5] → "1,3,5"，資料庫存成一個字串
    final String weekdaysText = sortedWeekdays.join(',');

    final Map<String, Object?> values = <String, Object?>{
      'workout_days': weekdays.length,
      'workout_weekdays': weekdaysText,
    };

    await db.update(
      'user_profile',
      values,
      where: 'id = 1',
    );
  }

  // ---------- weight_log：體重紀錄 ----------

  /// 記一筆體重（同一天覆蓋）。如果是今天，也順便更新個人資料裡的目前體重。
  Future<void> logWeight(String date, double weightKg) async {
    final Database db = await getDatabase;

    final Map<String, Object?> weightValues = <String, Object?>{
      'date': date,
      'weight_kg': weightKg,
    };

    await db.insert(
      'weight_log',
      weightValues,
      conflictAlgorithm: ConflictAlgorithm.replace, // 同一天已經有就覆蓋
    );

    final String today = _todayStr();
    if (date == today) {
      final Map<String, Object?> profileValues = <String, Object?>{
        'weight_kg': weightKg,
      };
      await db.update(
        'user_profile',
        profileValues,
        where: 'id = 1',
      );
    }
  }

  /// 取體重紀錄，日期新到舊，預設最近 90 筆。
  Future<List<WeightEntry>> getWeightLog({int limit = 90}) async {
    final Database db = await getDatabase;

    final List<Map<String, Object?>> rows = await db.query(
      'weight_log',
      orderBy: 'date DESC',
      limit: limit,
    );

    // 每一列 Map 轉成一個 WeightEntry 物件，放進清單
    final List<WeightEntry> entries = <WeightEntry>[];
    for (final Map<String, Object?> row in rows) {
      final WeightEntry entry = WeightEntry.fromMap(row);
      entries.add(entry);
    }
    return entries;
  }
}

/// 今天的日期字串，格式和資料庫一致，例如 "2026-11-17"(不補零)
String _todayStr() {
  final DateTime now = DateTime.now();
  final String year = now.year.toString();
  final String month = now.month.toString();
  final String day = now.day.toString();
  return '$year-$month-$day';
}
