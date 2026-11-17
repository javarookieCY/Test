import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb, visibleForTesting;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart';

import 'migrations.dart';

// 各張表的讀寫方法分在不同檔案(用 extension 加到 DatabaseService 上)。
// export：別的檔案只要 import database_service.dart，就會連這三個檔案一起拿到，
// 不用每個畫面都自己 import 三次。
export 'exercise_db.dart';
export 'food_db.dart';
export 'profile_db.dart';

/// 資料庫的入口：整個 App 只有一個(DatabaseService.instance)，負責打開資料庫。
/// 建表與升級在 migrations.dart；各張表的讀寫在 *_db.dart。
class DatabaseService {
  // 私有建構子(名字底線開頭 = Java 的 private)：別的檔案不能 new 一個 DatabaseService
  DatabaseService._createDatabase();

  // 全 App 唯一的一個(單例，singleton)
  static final DatabaseService instance = DatabaseService._createDatabase();

  // 操作 CRUD 的物件；還沒打開之前是 null
  Database? _db;

  // 桌面版的資料庫引擎設定過了沒(只需要設定一次)
  static bool _factoryInitialized = false;

  /// 拿到已經打開的資料庫；第一次呼叫時才真的打開。
  /// 這是 getter(相當於 Java 的 getDatabase() 方法)，使用時不加括號：await getDatabase
  Future<Database> get getDatabase async {
    // 先複製到區域變數，Dart 才能確定它檢查完之後不是 null
    final Database? existing = _db;
    if (existing != null) {
      return existing;
    }

    final Database opened = await _initDB();
    _db = opened;
    return opened;
  }

  void _ensureFactoryInitialized() {
    if (_factoryInitialized) {
      return;
    }

    // 因為 DevicePreview 屬於用 Windows 開啟的方法，要用桌面版的資料庫引擎
    // 先檢查不是網頁版：網頁上呼叫 Platform.isWindows 會直接報錯
    bool isDesktop = false;
    if (!kIsWeb) {
      if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
        isDesktop = true;
      }
    }

    if (isDesktop) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    _factoryInitialized = true;
  }

  /// 測試用：改開指定路徑的資料庫（例如 inMemoryDatabasePath），不會動到 App 自己的 meals.db。
  @visibleForTesting
  Future<void> openForTest(String path) async {
    final Database? existing = _db;
    if (existing != null) {
      await existing.close();
    }

    final Database opened = await _initDB(path: path);
    _db = opened;
  }

  /// 真的去打開資料庫檔案。path 沒給就用 App 自己的 meals.db。
  Future<Database> _initDB({String? path}) async {
    _ensureFactoryInitialized();

    String databasePath;
    if (path == null) {
      final String folder = await getDatabasesPath();
      databasePath = join(folder, 'meals.db');
    } else {
      databasePath = path;
    }

    // openDatabase 是 sqflite 套件的函式(和上面的 getDatabase 不一樣)
    final Database db = await openDatabase(
      databasePath,
      version: kDbVersion,
      onCreate: createDatabase, // 全新安裝時執行
      onUpgrade: upgradeDatabase, // 從舊版本升級時執行
    );

    await seedFoodRefIfEmpty(db);

    return db;
  }
}
