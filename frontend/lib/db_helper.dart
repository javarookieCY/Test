import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart';

// - 餐點庫的資料模型 -
// 代表「一種食物」的範本，例如：水煮蛋、地瓜、雞胸肉
class FoodItem {
  FoodItem({
    this.id,
    required this.name,
    required this.calories,
    this.protein = 0,
    this.carbs = 0,
    this.fat = 0,
    this.imagePath, // 圖片路徑（asset 路徑），可留空；有值才會顯示在「預設餐點」卡片牆
    this.description, // 內容物說明，例如：「大麥克 1份、可樂(中) 1杯、中薯 1份」
  });

  final int? id; // 資料庫的主鍵，新增前是 null，讀出來後才有值
  final String name;
  final int calories;
  final double protein;
  final double carbs;
  final double fat;
  final String? imagePath;
  final String? description;

  // 把物件轉成 sqflite 看得懂的 Map（給 insert 用）
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'calories': calories,
      'protein': protein,
      'carbs': carbs,
      'fat': fat,
      'image_path': imagePath,
      'description': description,
    };
  }

  // 把資料庫查出來的一筆 row（Map）轉回 FoodItem 物件（給 query 用）
  factory FoodItem.fromMap(Map<String, dynamic> map) {
    return FoodItem(
      id: map['id'] as int,
      name: map['name'] as String,
      calories: map['calories'] as int,
      protein: (map['protein'] as num).toDouble(),
      carbs: (map['carbs'] as num).toDouble(),
      fat: (map['fat'] as num).toDouble(),
      imagePath: map['image_path'] as String?,
      description: map['description'] as String?,
    );
  }
}

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

    return openDatabase(
      path,
      version: 4, // 版本升到 4，foods 多了 image_path / description（預設餐點卡片用）
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
      },
    );
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
}