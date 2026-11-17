import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../features/diet/food/food_item.dart';
import '../features/diet/food/nutrients.dart';
import '../models/food_ref_item.dart';
import 'database_service.dart';

/// 食物相關的四張表：meals、foods、meal_foods、food_ref
extension FoodDb on DatabaseService {
  // ---------- meals：每日飲食紀錄(舊設計，只寫不讀) ----------

  Future<int> insertMeal(String title, int calories, String date) async {
    final Database db = await getDatabase;
    final Map<String, Object?> values = <String, Object?>{
      'title': title,
      'calories': calories,
      'date': date,
    };
    final int id = await db.insert('meals', values);
    return id;
  }

  Future<List<Map<String, dynamic>>> getMealsByDate(String date) async {
    final Database db = await getDatabase;
    final List<Map<String, Object?>> rows = await db.query(
      'meals',
      where: 'date = ?',
      whereArgs: [date],
    );
    return rows;
  }

  // ---------- foods：使用者自訂的餐點庫 ----------

  /// 新增一種食物到餐點庫，回傳新的 id
  Future<int> insertFood(FoodItem food) async {
    final Database db = await getDatabase;
    final Map<String, dynamic> values = food.toMap();
    final int id = await db.insert('foods', values);
    return id;
  }

  /// 餐點庫裡所有食物，依名稱排序
  Future<List<FoodItem>> getAllFoods() async {
    final Database db = await getDatabase;
    final List<Map<String, Object?>> rows = await db.query(
      'foods',
      orderBy: 'name ASC',
    );

    final List<FoodItem> foods = <FoodItem>[];
    for (final Map<String, Object?> row in rows) {
      final FoodItem food = FoodItem.fromMap(row);
      foods.add(food);
    }
    return foods;
  }

  /// 從餐點庫刪除一種食物，回傳刪掉幾筆
  Future<int> deleteFood(int id) async {
    final Database db = await getDatabase;
    final int deletedCount = await db.delete(
      'foods',
      where: 'id = ?',
      whereArgs: [id],
    );
    return deletedCount;
  }

  /// 修改餐點庫裡的一種食物(用 food.id 找)，回傳改了幾筆
  Future<int> updateFood(FoodItem food) async {
    final Database db = await getDatabase;
    final Map<String, dynamic> values = food.toMap();
    final int updatedCount = await db.update(
      'foods',
      values,
      where: 'id = ?',
      whereArgs: [food.id],
    );
    return updatedCount;
  }

  // ---------- meal_foods：每天每餐吃了什麼 ----------

  /// 記錄某天某餐吃了某樣食物；同一天、同一餐、同名食物已經有就覆蓋。
  /// nutrients 是這筆紀錄的總量（已乘上份數），手動輸入熱量的傳 Nutrients.zero。
  Future<int> upsertMealFood(
    String date,
    String mealTitle,
    String foodName,
    int calories,
    double portion,
    Nutrients nutrients,
  ) async {
    final Database db = await getDatabase;

    final Map<String, Object?> values = <String, Object?>{
      'date': date,
      'meal_title': mealTitle,
      'food_name': foodName,
      'calories': calories,
      'portion': portion,
    };
    // 再把五種營養素(protein、carbs、fat、fiber、sodium)加進同一個 Map
    final Map<String, double> nutrientValues = nutrients.toMap();
    values.addAll(nutrientValues);

    final int id = await db.insert(
      'meal_foods',
      values,
      conflictAlgorithm: ConflictAlgorithm.replace, // UNIQUE(date, meal_title, food_name) 重複就覆蓋
    );
    return id;
  }

  /// 刪除某天某餐的某樣食物，回傳刪掉幾筆
  Future<int> deleteMealFood(String date, String mealTitle, String foodName) async {
    final Database db = await getDatabase;
    final int deletedCount = await db.delete(
      'meal_foods',
      where: 'date = ? AND meal_title = ? AND food_name = ?',
      whereArgs: [date, mealTitle, foodName],
    );
    return deletedCount;
  }

  /// 某一天的所有飲食紀錄。
  /// SQL：SELECT * FROM meal_foods WHERE date = 'xxxx-x-x'
  /// 回傳一個清單，每個 Map 是一列資料，key 是欄位名稱，例如 row['calories']。
  Future<List<Map<String, dynamic>>> getMealFoodsByDate(String date) async {
    final Database db = await getDatabase;
    final List<Map<String, Object?>> rows = await db.query(
      'meal_foods',
      where: 'date = ?',
      whereArgs: [date],
    );
    return rows;
  }

  /// 一次撈多天的飲食明細（統計頁「一週」用）。
  /// 日期字串不是補零格式，不能用 BETWEEN，改用 IN，例如 date IN (?, ?, ?)。
  Future<List<Map<String, dynamic>>> getMealFoodsByDates(List<String> dates) async {
    if (dates.isEmpty) {
      return <Map<String, dynamic>>[];
    }

    final Database db = await getDatabase;

    // 有幾個日期就放幾個 ?，例如 "?, ?, ?"
    final List<String> marks = <String>[];
    for (int i = 0; i < dates.length; i++) {
      marks.add('?');
    }
    final String placeholders = marks.join(', ');

    final List<Map<String, Object?>> rows = await db.query(
      'meal_foods',
      where: 'date IN ($placeholders)',
      whereArgs: dates,
    );
    return rows;
  }

  // ---------- food_ref：TFDA 食品營養成分參考庫（唯讀） ----------

  /// food_ref 一共有幾筆
  Future<int> getFoodRefCount() async {
    final Database db = await getDatabase;
    final List<Map<String, Object?>> rows = await db.rawQuery('SELECT COUNT(*) AS c FROM food_ref');

    final Map<String, Object?> firstRow = rows.first;
    final Object? count = firstRow['c'];
    if (count == null) {
      return 0;
    }
    return count as int;
  }

  /// 用關鍵字搜尋官方食品庫(名稱或俗名)，最多 limit 筆。
  /// 排序：名稱完全一樣 → 名稱開頭符合 → 其他；同一級再依名稱長度、名稱排。
  Future<List<FoodRefItem>> searchFoodRef(String keyword, {int limit = 30}) async {
    final Database db = await getDatabase;

    final String trimmedKeyword = keyword.trim();
    if (trimmedKeyword.isEmpty) {
      return <FoodRefItem>[];
    }

    final String contains = '%$trimmedKeyword%'; // LIKE 的 % 代表任意文字：名稱裡有這個字
    final String startsWith = '$trimmedKeyword%'; // 名稱以這個字開頭

    final List<Map<String, Object?>> rows = await db.rawQuery(
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
      [contains, contains, startsWith, contains, limit],
    );

    final List<FoodRefItem> items = <FoodRefItem>[];
    for (final Map<String, Object?> row in rows) {
      final FoodRefItem item = FoodRefItem.fromMap(row);
      items.add(item);
    }
    return items;
  }

  /// 用整合編號找一筆官方食品；找不到回傳 null
  Future<FoodRefItem?> getFoodRefByCode(String refCode) async {
    final Database db = await getDatabase;
    final List<Map<String, Object?>> rows = await db.query(
      'food_ref',
      where: 'ref_code = ?',
      whereArgs: [refCode],
      limit: 1,
    );

    if (rows.isEmpty) {
      return null;
    }

    final Map<String, Object?> firstRow = rows.first;
    final FoodRefItem item = FoodRefItem.fromMap(firstRow);
    return item;
  }
}
