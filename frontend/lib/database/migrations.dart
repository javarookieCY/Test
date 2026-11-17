import 'dart:convert';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/services.dart' show rootBundle;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../models/food_ref_item.dart';
import '../utils/exercise_catalog.dart';

// ── 建表與升級 ──────────────────────────────
// 每次改資料表結構，kDbVersion 加 1，並在 upgradeDatabase 補上那一版要做的事。
//   全新安裝 → createDatabase：一次建出最新的所有表
//   舊版本   → upgradeDatabase：從舊版本一層一層補到最新

const int kDbVersion = 15;

/// 全新安裝時執行
Future<void> createDatabase(Database db, int version) async {
  await db.execute('''
    CREATE TABLE meals (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      title TEXT NOT NULL,
      calories INTEGER NOT NULL,
      date TEXT NOT NULL
    )
  ''');
  await db.execute('''
    CREATE TABLE foods (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      calories INTEGER NOT NULL,
      protein REAL NOT NULL DEFAULT 0,
      carbs REAL NOT NULL DEFAULT 0,
      fat REAL NOT NULL DEFAULT 0,
      image_path TEXT,
      description TEXT
    )
  ''');
  await db.execute('''
    CREATE TABLE meal_foods (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      date TEXT NOT NULL,
      meal_title TEXT NOT NULL,
      food_name TEXT NOT NULL,
      calories INTEGER NOT NULL,
      portion REAL NOT NULL,
      UNIQUE(date, meal_title, food_name)
    )
  ''');
  await db.execute(_createFoodRefSql);
  await db.execute(_createUserProfileSql);
  await db.execute(_createWeightLogSql);
  await db.execute(_createExercisesSql);
  await db.execute(_createExerciseTasksSql);
  await _addExerciseTaskDetailColumns(db);
  await _addWorkoutDaysColumn(db);
  await _addNutrientColumns(db);
  await _addEquipmentColumn(db);
  await _addWorkoutWeekdaysColumn(db);
}

/// 手機上已經有舊版本的資料庫時執行
Future<void> upgradeDatabase(Database db, int oldVersion, int newVersion) async {
  if (oldVersion < 2) {
    await db.execute('''
      CREATE TABLE foods (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        calories INTEGER NOT NULL,
        protein REAL NOT NULL DEFAULT 0,
        carbs REAL NOT NULL DEFAULT 0,
        fat REAL NOT NULL DEFAULT 0
      )
    ''');
  }
  if (oldVersion < 3) {
    await db.execute('''
      CREATE TABLE meal_foods (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT NOT NULL,
        meal_title TEXT NOT NULL,
        food_name TEXT NOT NULL,
        calories INTEGER NOT NULL,
        portion REAL NOT NULL,
        UNIQUE(date, meal_title, food_name)
      )
    ''');
  }
  if (oldVersion < 4) {
    await db.execute('ALTER TABLE foods ADD COLUMN image_path TEXT');
    await db.execute('ALTER TABLE foods ADD COLUMN description TEXT');
  }
  if (oldVersion < 5) {
    await db.execute(_createFoodRefSql);
  }
  if (oldVersion < 6) {
    await db.execute(_createUserProfileSql);
    await db.execute(_createWeightLogSql);
  }
  if (oldVersion < 7) {
    // exercises 在更早的版本可能已被手動建立，用 IF NOT EXISTS 保險
    await db.execute(_createExercisesSql);
  }
  // 版本 8 曾經建立 water_log(喝水紀錄)，版本 15 已移除，這裡不再建立
  if (oldVersion < 9) {
    await db.execute(_createExerciseTasksSql);
  }
  if (oldVersion < 10) {
    await _addExerciseTaskDetailColumns(db);
  }
  if (oldVersion < 11) {
    await _addWorkoutDaysColumn(db);
  }
  if (oldVersion < 12) {
    await _addNutrientColumns(db);
    await _backfillMealFoodNutrients(db);
  }
  if (oldVersion < 13) {
    await _addEquipmentColumn(db);
    await _deleteTasksNotInCatalog(db);
  }
  if (oldVersion < 14) {
    await _addWorkoutWeekdaysColumn(db);
  }
  if (oldVersion < 15) {
    // 移除喝水功能：舊資料庫的 water_log 整張表刪掉
    await db.execute('DROP TABLE IF EXISTS water_log');
  }
}

const String _createFoodRefSql = '''
  CREATE TABLE food_ref (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    ref_code TEXT NOT NULL UNIQUE,
    name TEXT NOT NULL,
    alias TEXT,
    category TEXT,
    calories INTEGER NOT NULL,
    protein REAL,
    carbs REAL,
    fat REAL,
    fiber REAL,
    sodium REAL,
    water REAL
  )
''';

const String _createUserProfileSql = '''
  CREATE TABLE user_profile (
    id INTEGER PRIMARY KEY CHECK (id = 1),
    height_cm REAL NOT NULL,
    weight_kg REAL NOT NULL,
    age INTEGER NOT NULL,
    sex TEXT NOT NULL,
    activity_level TEXT NOT NULL,
    goal TEXT NOT NULL
  )
''';

const String _createWeightLogSql = '''
  CREATE TABLE weight_log (
    date TEXT PRIMARY KEY,
    weight_kg REAL NOT NULL
  )
''';

const String _createExercisesSql = '''
  CREATE TABLE IF NOT EXISTS exercises (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    date TEXT NOT NULL,
    name TEXT NOT NULL,
    minutes INTEGER NOT NULL,
    calories INTEGER NOT NULL
  )
''';

const String _createExerciseTasksSql = '''
  CREATE TABLE IF NOT EXISTS exercise_tasks (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    date TEXT NOT NULL,
    category TEXT NOT NULL,
    name TEXT NOT NULL,
    done INTEGER NOT NULL DEFAULT 0
  )
''';

/// sets（重訓組數）/ minutes（有氧分鐘數）是版本 10 才加的欄位，
/// 用 ALTER TABLE 補上，新舊資料庫都能吃到同一份邏輯。
Future<void> _addExerciseTaskDetailColumns(Database db) async {
  await db.execute('ALTER TABLE exercise_tasks ADD COLUMN sets INTEGER');
  await db.execute('ALTER TABLE exercise_tasks ADD COLUMN minutes INTEGER');
}

Future<void> _addWorkoutDaysColumn(Database db) async {
  await db.execute('ALTER TABLE user_profile ADD COLUMN workout_days INTEGER NOT NULL DEFAULT 3');
}

/// 版本 12：餐點庫多記纖維 / 鈉，飲食紀錄多記五種營養素（已乘上份數），
/// 統計頁才有熱量以外的數字可以加總。
Future<void> _addNutrientColumns(Database db) async {
  final List<String> foodsColumns = <String>['fiber', 'sodium'];
  for (final String column in foodsColumns) {
    await db.execute('ALTER TABLE foods ADD COLUMN $column REAL NOT NULL DEFAULT 0');
  }

  final List<String> mealFoodsColumns = <String>['protein', 'carbs', 'fat', 'fiber', 'sodium'];
  for (final String column in mealFoodsColumns) {
    await db.execute('ALTER TABLE meal_foods ADD COLUMN $column REAL NOT NULL DEFAULT 0');
  }
}

/// 版本 13：個人資料記「有哪些器材」。舊資料預設徒手 + 啞鈴（升級前的計畫就是用這兩種排的）。
Future<void> _addEquipmentColumn(Database db) async {
  await db.execute(
      "ALTER TABLE user_profile ADD COLUMN equipment TEXT NOT NULL DEFAULT 'bodyweight,dumbbell'");
}

/// 版本 14：個人資料記「每週哪幾天運動」（例如 "1,3,5"）。
/// 舊資料是 null，讀出來時依原本的每週天數給預設的運動日。
Future<void> _addWorkoutWeekdaysColumn(Database db) async {
  await db.execute('ALTER TABLE user_profile ADD COLUMN workout_weekdays TEXT');
}

/// 版本 13：訓練清單改成只能從動作庫挑，以前自己取名的動作整筆刪掉。
Future<void> _deleteTasksNotInCatalog(Database db) async {
  // 動作庫裡所有動作的名稱
  final List<String> names = <String>[];
  for (final ExerciseDef exercise in kExerciseCatalog) {
    names.add(exercise.name);
  }

  // 有幾個名稱就放幾個 ?，例如 "?, ?, ?"
  final List<String> marks = <String>[];
  for (int i = 0; i < names.length; i++) {
    marks.add('?');
  }
  final String placeholders = marks.join(', ');

  await db.delete(
    'exercise_tasks',
    where: 'name NOT IN ($placeholders)',
    whereArgs: names,
  );
}

/// 升級前的飲食紀錄沒有營養素：用「同名的餐點庫食物 × 份數」盡量補回去。
/// 找不到同名食物的（例如手動輸入熱量）維持 0。
Future<void> _backfillMealFoodNutrients(Database db) async {
  // 每個營養素組出一段，例如：
  // protein = portion * (SELECT f.protein FROM foods f WHERE f.name = meal_foods.food_name ORDER BY f.id LIMIT 1)
  final List<String> columns = <String>['protein', 'carbs', 'fat'];
  final List<String> assignments = <String>[];
  for (final String column in columns) {
    final String assignment = '$column = portion * (SELECT f.$column FROM foods f '
        'WHERE f.name = meal_foods.food_name ORDER BY f.id LIMIT 1)';
    assignments.add(assignment);
  }
  final String setClause = assignments.join(', ');

  await db.execute('''
    UPDATE meal_foods SET $setClause
    WHERE EXISTS (SELECT 1 FROM foods f WHERE f.name = meal_foods.food_name)
  ''');
}

const String _foodRefAsset = 'assets/data/food_ref.json';

/// 第一次開資料庫時，把官方食品資料(json)匯入 food_ref；已經有資料就跳過。
Future<void> seedFoodRefIfEmpty(Database db) async {
  // 先數 food_ref 有幾筆
  final List<Map<String, Object?>> countRows =
      await db.rawQuery('SELECT COUNT(*) AS c FROM food_ref');
  final Object? countValue = countRows.first['c'];
  int count = 0;
  if (countValue != null) {
    count = countValue as int;
  }

  // 已經有資料：不用再匯入
  if (count > 0) {
    return;
  }

  try {
    // 讀 json 檔的文字內容
    final String raw = await rootBundle.loadString(_foodRefAsset);

    // json 文字 → List，裡面每個元素是一個食物的 Map
    final List<dynamic> decoded = jsonDecode(raw) as List<dynamic>;
    final List<Map<String, dynamic>> foods = <Map<String, dynamic>>[];
    for (final dynamic element in decoded) {
      foods.add(element as Map<String, dynamic>);
    }

    // transaction：要嘛全部寫入成功，要嘛全部不寫
    // batch：把很多筆 insert 收集起來一次送出，比一筆一筆快很多
    await db.transaction((Transaction txn) async {
      final Batch batch = txn.batch();
      for (final Map<String, dynamic> json in foods) {
        final FoodRefItem item = FoodRefItem.fromJson(json);
        batch.insert('food_ref', item.toMap());
      }
      await batch.commit(noResult: true);
    });

    final int total = foods.length;
    debugPrint('food_ref 首次載入完成：$total 筆');
  } catch (e) {
    debugPrint('food_ref 載入失敗（$_foodRefAsset）: $e');
  }
}
