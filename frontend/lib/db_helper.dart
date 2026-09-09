import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter/services.dart' show rootBundle;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart';

import 'models/exercise_entry.dart';
import 'models/food_item.dart';
import 'models/food_ref_item.dart';
import 'models/user_profile.dart';

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

  // sqflite 原生只支援 Android / iOS。
  // 在 Windows / macOS / Linux 桌面環境跑的時候，
  // 要改用 sqflite_common_ffi 提供的桌面版實作，否則會出現
  // "databaseFactory not initialized" 的錯誤。
  void _ensureFactoryInitialized() {
    if (_factoryInitialized) return; // 只需要初始化一次

    final isDesktop = !kIsWeb &&
        (Platform.isWindows || Platform.isLinux || Platform.isMacOS);

    if (isDesktop) {
      sqfliteFfiInit(); // 初始化 ffi 底層(載入對應平台的 sqlite3 函式庫)
      databaseFactory = databaseFactoryFfi; // 把「開資料庫」的實作換成桌面版
    }
    // Android / iOS 維持原本 sqflite 內建的 databaseFactory，不用做任何事

    _factoryInitialized = true;
  }

  Future<Database> _initDB() async {
    _ensureFactoryInitialized();

    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'meals.db');

    final db = await openDatabase(
      path,
      version: 7, // 版本升到 7，把 exercises（運動紀錄）納入正式 schema
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
      },
      // 如果使用者手機裡已經有舊版的資料庫，這裡負責「補上」新表
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
      },
    );

    // 建表(或升級)後，若 food_ref 還是空的就從 asset 灌資料進去。
    // 放在 openDatabase 之外，onCreate / onUpgrade 兩條路徑都會涵蓋到。
    await _seedFoodRefIfEmpty(db);

    return db;
  }

  // food_ref：衛福部 TFDA 食品營養成分參考庫（唯讀）。
  // 資料由 tools/import_nutrition/build_food_ref.py 產出成
  // assets/data/food_ref.json，首次啟動時載入。所有數值皆為「每 100 克」含量。
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

  // user_profile：個人化目標的來源資料，只存一列（id 固定 1）。
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

  // weight_log：每日體重紀錄，之後做「動態微調目標」會用到趨勢。
  static const _createWeightLogSql = '''
    CREATE TABLE weight_log (
      date TEXT PRIMARY KEY,
      weight_kg REAL NOT NULL
    )
  ''';

  // exercises：運動紀錄。消耗熱量會回饋到首頁「剩餘熱量」計算。
  static const _createExercisesSql = '''
    CREATE TABLE IF NOT EXISTS exercises (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      date TEXT NOT NULL,
      name TEXT NOT NULL,
      minutes INTEGER NOT NULL,
      calories INTEGER NOT NULL
    )
  ''';

  // 若 food_ref 沒有資料，讀 JSON asset 用單一 transaction 批次寫入。
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
  Future<int> upsertMealFood(String date, String mealTitle, String foodName, int calories, double portion) async {
    final db = await database;
    return db.insert('meal_foods', {
      'date': date,
      'meal_title': mealTitle,
      'food_name': foodName,
      'calories': calories,
      'portion': portion,
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

  // ---------- food_ref：TFDA 食品營養成分參考庫（唯讀） ----------
  Future<int> getFoodRefCount() async {
    final db = await database;
    final rows = await db.rawQuery('SELECT COUNT(*) AS c FROM food_ref');
    return (rows.first['c'] as int?) ?? 0;
  }

  // 依名稱 / 俗名關鍵字搜尋（給使用者從參考庫挑食物用）。
  // 排序：名稱開頭命中 > 名稱包含 > 只有俗名命中，同組再按名稱長度、筆劃。
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
}