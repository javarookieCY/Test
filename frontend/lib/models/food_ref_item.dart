// - 食品營養成分參考庫的資料模型 -
// 對應 SQLite 的 food_ref 表，資料來源是衛福部 TFDA 食品營養成分資料庫
// (由 tools/import_nutrition/build_food_ref.py 從 data/20_2.csv 摺疊產出)。
//
// 這是「唯讀參考資料」，跟使用者自訂的 foods（FoodItem）分開：
// 使用者可以從這裡搜尋，再把某一筆「複製」進自己的餐點庫。
// 所有數值都是「每 100 克」的含量。
class FoodRefItem {
  FoodRefItem({
    this.id,
    required this.refCode,
    required this.name,
    this.alias,
    this.category,
    required this.calories,
    this.protein,
    this.carbs,
    this.fat,
    this.fiber,
    this.sodium,
    this.water,
  });

  final int? id;
  final String refCode; // 整合編號，例如 B0700201
  final String name; // 樣品名稱
  final String? alias; // 俗名（逗號分隔），可能為 null
  final String? category; // 食品分類

  // 每 100 克含量。calories 一定有值；其餘營養素少數樣品缺值，為 null。
  final int calories; // kcal（原始為熱量，匯入時四捨五入成整數）
  final double? protein; // g
  final double? carbs; // g（來源：總碳水化合物）
  final double? fat; // g
  final double? fiber; // g（膳食纖維）
  final double? sodium; // mg
  final double? water; // g

  factory FoodRefItem.fromMap(Map<String, dynamic> map) {
    double? d(Object? v) => v == null ? null : (v as num).toDouble();
    return FoodRefItem(
      id: map['id'] as int?,
      refCode: map['ref_code'] as String,
      name: map['name'] as String,
      alias: map['alias'] as String?,
      category: map['category'] as String?,
      calories: (map['calories'] as num).round(),
      protein: d(map['protein']),
      carbs: d(map['carbs']),
      fat: d(map['fat']),
      fiber: d(map['fiber']),
      sodium: d(map['sodium']),
      water: d(map['water']),
    );
  }

  // 從 build_food_ref.py 產出的 JSON 物件建立（給首次載入 asset 時用）
  factory FoodRefItem.fromJson(Map<String, dynamic> json) {
    double? d(Object? v) => v == null ? null : (v as num).toDouble();
    return FoodRefItem(
      refCode: json['ref_code'] as String,
      name: json['name'] as String,
      alias: json['alias'] as String?,
      category: json['category'] as String?,
      calories: (json['calories'] as num).round(),
      protein: d(json['protein']),
      carbs: d(json['carbs']),
      fat: d(json['fat']),
      fiber: d(json['fiber']),
      sodium: d(json['sodium']),
      water: d(json['water']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'ref_code': refCode,
      'name': name,
      'alias': alias,
      'category': category,
      'calories': calories,
      'protein': protein,
      'carbs': carbs,
      'fat': fat,
      'fiber': fiber,
      'sodium': sodium,
      'water': water,
    };
  }
}
