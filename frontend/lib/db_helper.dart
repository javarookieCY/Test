import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint, visibleForTesting;
import 'package:flutter/services.dart' show rootBundle;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart';

import 'models/exercise_entry.dart';
import 'models/exercise_task.dart';
import 'models/food_item.dart';
import 'models/food_ref_item.dart';
import 'models/nutrients.dart';
import 'models/user_profile.dart';
import 'models/water_entry.dart';
import 'utils/exercise_catalog.dart';

class DBHelper {
  DBHelper._();
  static final DBHelper instance = DBHelper._();
  Database? _db;
  static bool _factoryInitialized = false;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDB();
    return _db!;
  }

  void _ensureFactoryInitialized() {
    if (_factoryInitialized) return; 

    final isDesktop = !kIsWeb &&
        (Platform.isWindows || Platform.isLinux || Platform.isMacOS);

    if (isDesktop) {
      sqfliteFfiInit(); 
      databaseFactory = databaseFactoryFfi; 
    }

    _factoryInitialized = true;
  }

  /// 測試用：改開指定路徑的資料庫（例如 inMemoryDatabasePath），不會動到 App 自己的 meals.db。
  @visibleForTesting
  Future<void> openForTest(String path) async {
    await _db?.close();
    _db = await _initDB(path: path);
  }

  Future<Database> _initDB({String? path}) async {
    _ensureFactoryInitialized();

    path ??= join(await getDatabasesPath(), 'meals.db');

    final db = await openDatabase(
      path,
      version: 14,
      onCreate: (db, version) async {
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
        await db.execute(_createWaterLogSql);
        await db.execute(_createExerciseTasksSql);
        await _addExerciseTaskDetailColumns(db);
        await _addWorkoutDaysColumn(db);
        await _addNutrientColumns(db);
        await _addEquipmentColumn(db);
        await _addWorkoutWeekdaysColumn(db);
      },

      onUpgrade: (db, oldVersion, newVersion) async {
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
        if (oldVersion < 8) {
          await db.execute(_createWaterLogSql);
        }
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
      },
    );

    await _seedFoodRefIfEmpty(db);

    return db;
  }

  static const _createFoodRefSql = '''
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

  static const _foodRefAsset = 'assets/data/food_ref.json';


  static const _createUserProfileSql = '''
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

  static const _createWeightLogSql = '''
    CREATE TABLE weight_log (
      date TEXT PRIMARY KEY,
      weight_kg REAL NOT NULL
    )
  ''';

  static const _createExercisesSql = '''
    CREATE TABLE IF NOT EXISTS exercises (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      date TEXT NOT NULL,
      name TEXT NOT NULL,
      minutes INTEGER NOT NULL,
      calories INTEGER NOT NULL
    )
  ''';

  static const _createWaterLogSql = '''
    CREATE TABLE IF NOT EXISTS water_log (
      date TEXT PRIMARY KEY,
      consumed_ml INTEGER NOT NULL,
      target_ml INTEGER NOT NULL
    )
  ''';

  static const _createExerciseTasksSql = '''
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
    for (final col in ['fiber', 'sodium']) {
      await db.execute('ALTER TABLE foods ADD COLUMN $col REAL NOT NULL DEFAULT 0');
    }
    for (final col in ['protein', 'carbs', 'fat', 'fiber', 'sodium']) {
      await db.execute('ALTER TABLE meal_foods ADD COLUMN $col REAL NOT NULL DEFAULT 0');
    }
  }

  /// 升級前的飲食紀錄沒有營養素：用「同名的餐點庫食物 × 份數」盡量補回去。
  /// 找不到同名食物的（例如手動輸入熱量）維持 0。
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
    final names = kExerciseCatalog.map((e) => e.name).toList();
    final marks = List.filled(names.length, '?').join(', ');
    await db.delete('exercise_tasks', where: 'name NOT IN ($marks)', whereArgs: names);
  }

  Future<void> _backfillMealFoodNutrients(Database db) async {
    String perPortion(String col) =>
        '$col = portion * (SELECT f.$col FROM foods f '
        'WHERE f.name = meal_foods.food_name ORDER BY f.id LIMIT 1)';
    await db.execute('''
      UPDATE meal_foods SET ${['protein', 'carbs', 'fat'].map(perPortion).join(', ')}
      WHERE EXISTS (SELECT 1 FROM foods f WHERE f.name = meal_foods.food_name)
    ''');
  }

  Future<void> _seedFoodRefIfEmpty(Database db) async {
    final rows = await db.rawQuery('SELECT COUNT(*) AS c FROM food_ref');
    final count = (rows.first['c'] as int?) ?? 0;
    if (count > 0) return;

    try {
      final raw = await rootBundle.loadString(_foodRefAsset);
      final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();

      await db.transaction((txn) async {
        final batch = txn.batch();
        for (final json in list) {
          batch.insert('food_ref', FoodRefItem.fromJson(json).toMap());
        }
        await batch.commit(noResult: true);
      });
      debugPrint('food_ref 首次載入完成：${list.length} 筆');
    } catch (e) {
      debugPrint('food_ref 載入失敗（$_foodRefAsset）: $e');
    }
  }

  // ---------- meals：每日飲食紀錄 ----------
  Future<int> insertMeal(String title, int calories, String date) async {
    final db = await database;
    return db.insert('meals', {
      'title': title,
      'calories': calories,
      'date': date,
    });
  }

  Future<List<Map<String, dynamic>>> getMealsByDate(String date) async {
    final db = await database;
    return db.query('meals', where: 'date = ?', whereArgs: [date]);
  }

  // ---------- foods：使用者自訂的餐點庫 ----------
  Future<int> insertFood(FoodItem food) async {
    final db = await database;
    return db.insert('foods', food.toMap());
  }

  Future<List<FoodItem>> getAllFoods() async {
    final db = await database;
    final rows = await db.query('foods', orderBy: 'name ASC');
    return rows.map((row) => FoodItem.fromMap(row)).toList();
  }

  Future<int> deleteFood(int id) async {
    final db = await database;
    return db.delete('foods', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> updateFood(FoodItem food) async {
    final db = await database;
    return db.update('foods', food.toMap(), where: 'id = ?', whereArgs: [food.id]);
  }

  // ---------- meal_foods：詳細餐點紀錄 ----------
  /// [nutrients] 是這筆紀錄的總量（已乘上份數），手動輸入熱量的傳 Nutrients.zero。
  Future<int> upsertMealFood(String date, String mealTitle, String foodName, int calories,
      double portion, Nutrients nutrients) async {
    final db = await database;
    return db.insert('meal_foods', {
      'date': date,
      'meal_title': mealTitle,
      'food_name': foodName,
      'calories': calories,
      'portion': portion,
      ...nutrients.toMap(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<int> deleteMealFood(String date, String mealTitle, String foodName) async {
    final db = await database;
    return db.delete('meal_foods', 
      where: 'date = ? AND meal_title = ? AND food_name = ?', 
      whereArgs: [date, mealTitle, foodName]);
  }

  Future<List<Map<String, dynamic>>> getMealFoodsByDate(String date) async {
    final db = await database;
    return db.query('meal_foods', where: 'date = ?', whereArgs: [date]);
  }

  /// 一次撈多天的飲食明細（統計頁「一週」用）。日期字串不是補零格式，不能用 BETWEEN，改用 IN。
  Future<List<Map<String, dynamic>>> getMealFoodsByDates(List<String> dates) async {
    if (dates.isEmpty) return const [];
    final db = await database;
    final marks = List.filled(dates.length, '?').join(', ');
    return db.query('meal_foods', where: 'date IN ($marks)', whereArgs: dates);
  }

  // ---------- food_ref：TFDA 食品營養成分參考庫（唯讀） ----------
  Future<int> getFoodRefCount() async {
    final db = await database;
    final rows = await db.rawQuery('SELECT COUNT(*) AS c FROM food_ref');
    return (rows.first['c'] as int?) ?? 0;
  }

  Future<List<FoodRefItem>> searchFoodRef(String keyword, {int limit = 30}) async {
    final db = await database;
    final kw = keyword.trim();
    if (kw.isEmpty) return const [];

    final like = '%$kw%';
    final prefix = '$kw%';
    final rows = await db.rawQuery(
      '''
      SELECT * FROM food_ref
      WHERE name LIKE ? OR alias LIKE ?
      ORDER BY
        CASE
          WHEN name LIKE ? THEN 0
          WHEN name LIKE ? THEN 1
          ELSE 2
        END,
        length(name) ASC,
        name ASC
      LIMIT ?
      ''',
      [like, like, prefix, like, limit],
    );
    return rows.map(FoodRefItem.fromMap).toList();
  }

  Future<FoodRefItem?> getFoodRefByCode(String refCode) async {
    final db = await database;
    final rows = await db.query(
      'food_ref',
      where: 'ref_code = ?',
      whereArgs: [refCode],
      limit: 1,
    );
    return rows.isEmpty ? null : FoodRefItem.fromMap(rows.first);
  }

  // ---------- user_profile：個人化目標 ----------
  Future<UserProfile?> getUserProfile() async {
    final db = await database;
    final rows = await db.query('user_profile', where: 'id = 1', limit: 1);
    return rows.isEmpty ? null : UserProfile.fromMap(rows.first);
  }

  /// 存個人資料（upsert id=1），同時把當天體重寫進 weight_log。
  Future<void> saveUserProfile(UserProfile profile) async {
    final db = await database;
    await db.insert(
      'user_profile',
      profile.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    await logWeight(_todayStr(), profile.weightKg);
  }

  /// 只改每週運動日（本週計畫頁點圓圈時用），不像 saveUserProfile 會順便記一筆體重。
  Future<void> updateWorkoutWeekdays(Set<int> weekdays) async {
    final db = await database;
    await db.update(
      'user_profile',
      {
        'workout_days': weekdays.length,
        'workout_weekdays': (weekdays.toList()..sort()).join(','),
      },
      where: 'id = 1',
    );
  }

  // ---------- weight_log：體重紀錄 ----------
  /// 記一筆體重（同一天覆蓋）。若和 user_profile 的日期相同也順便更新目前體重。
  Future<void> logWeight(String date, double weightKg) async {
    final db = await database;
    await db.insert(
      'weight_log',
      {'date': date, 'weight_kg': weightKg},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    if (date == _todayStr()) {
      await db.update(
        'user_profile',
        {'weight_kg': weightKg},
        where: 'id = 1',
      );
    }
  }

  /// 取體重紀錄，日期新到舊，預設最近 90 筆。
  Future<List<WeightEntry>> getWeightLog({int limit = 90}) async {
    final db = await database;
    final rows = await db.query(
      'weight_log',
      orderBy: 'date DESC',
      limit: limit,
    );
    return rows.map(WeightEntry.fromMap).toList();
  }

  static String _todayStr() {
    final d = DateTime.now();
    return '${d.year}-${d.month}-${d.day}';
  }

  // ---------- exercises：運動紀錄 ----------
  Future<int> insertExercise(ExerciseEntry entry) async {
    final db = await database;
    return db.insert('exercises', entry.toMap());
  }

  Future<List<ExerciseEntry>> getExercisesByDate(String date) async {
    final db = await database;
    final rows = await db.query(
      'exercises',
      where: 'date = ?',
      whereArgs: [date],
      orderBy: 'id DESC',
    );
    return rows.map(ExerciseEntry.fromMap).toList();
  }

  Future<int> deleteExercise(int id) async {
    final db = await database;
    return db.delete('exercises', where: 'id = ?', whereArgs: [id]);
  }

  /// 某一天運動消耗的總熱量（給首頁「剩餘熱量」加回去）。
  Future<int> getBurnedCaloriesByDate(String date) async {
    final db = await database;
    final rows = await db.rawQuery(
      'SELECT COALESCE(SUM(calories), 0) AS c FROM exercises WHERE date = ?',
      [date],
    );
    return (rows.first['c'] as int?) ?? 0;
  }

  // ---------- exercise_tasks：今日訓練清單 ----------
  Future<int> insertExerciseTask(ExerciseTask task) async {
    final db = await database;
    return db.insert('exercise_tasks', task.toMap());
  }

  /// 依「重訓 → 有氧 → 伸展」排序，同分類內依新增順序排列。
  Future<List<ExerciseTask>> getExerciseTasksByDate(String date) async {
    final db = await database;
    final rows = await db.query(
      'exercise_tasks',
      where: 'date = ?',
      whereArgs: [date],
      orderBy: "CASE category WHEN 'cardio' THEN 1 WHEN 'flexibility' THEN 2 ELSE 0 END, id ASC",
    );
    return rows.map(ExerciseTask.fromMap).toList();
  }

  Future<int> setExerciseTaskDone(int id, bool done) async {
    final db = await database;
    return db.update(
      'exercise_tasks',
      {'done': done ? 1 : 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteExerciseTask(int id) async {
    final db = await database;
    return db.delete('exercise_tasks', where: 'id = ?', whereArgs: [id]);
  }

  /// 修改清單裡某個動作的組數（重訓）或分鐘數（有氧 / 伸展）。
  Future<int> updateExerciseTaskAmount(int id, {int? sets, int? minutes}) async {
    final db = await database;
    return db.update(
      'exercise_tasks',
      {'sets': sets, 'minutes': minutes},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// 把自動產生的運動計畫寫進 exercise_tasks。
  /// [tasksByDate] 的 key 是日期 (yyyy-M-d)。已經有打勾任務的那天整天跳過，
  /// 其餘日期先清空再寫入，避免跟舊清單重複。
  Future<void> applyWeeklyPlan(Map<String, List<ExerciseTask>> tasksByDate) async {
    final db = await database;
    await db.transaction((txn) async{
      for(final entry in tasksByDate.entries) {
        final date = entry.key;

        final doneRows = await txn.query(
          'exercise_tasks',
          where: 'date = ? AND done = 1',
          whereArgs: [date],
          limit: 1,
        );

        if(doneRows.isNotEmpty) continue;
        
        await txn.delete(
          'exercise_tasks',
          where: 'date = ?',
          whereArgs: [date]
        );

        for(final task in entry.value) {
          await txn.insert('exercise_tasks', task.toMap());
        }
      }
    },);
  }
  // ---------- water_log：喝水紀錄 ----------
  Future<WaterEntry?> getWaterLog(String date) async {
    final db = await database;
    final rows = await db.query(
      'water_log',
      where: 'date = ?',
      whereArgs: [date],
      limit: 1,
    );
    return rows.isEmpty ? null : WaterEntry.fromMap(rows.first);
  }

  /// 存今天的喝水紀錄（同一天覆蓋）。
  Future<void> saveWaterLog(String date, int consumedMl, int targetMl) async {
    final db = await database;
    await db.insert(
      'water_log',
      {'date': date, 'consumed_ml': consumedMl, 'target_ml': targetMl},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// 目標是「持續性設定」而非每天重填：今天還沒存過的話，就沿用最近一次存過的目標。
  Future<int?> getLatestWaterTarget() async {
    final db = await database;
    final rows = await db.query('water_log', orderBy: 'date DESC', limit: 1);
    if (rows.isEmpty) return null;
    return (rows.first['target_ml'] as num).toInt();
  }
}