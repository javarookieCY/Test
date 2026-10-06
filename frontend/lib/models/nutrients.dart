/// 熱量以外的營養素（熱量另外用 int 存，沿用既有的程式）。
/// 用在三個地方：餐點庫的一份食物、一筆飲食紀錄（已乘上份數）、統計頁的每日加總。
/// 欄位名稱跟 foods / meal_foods 表的欄位一致，toMap / fromMap 可以直接對 DB。
class Nutrients {
  const Nutrients({
    this.protein = 0,
    this.carbs = 0,
    this.fat = 0,
    this.fiber = 0,
    this.sodium = 0,
  });

  static const zero = Nutrients();

  final double protein; // g
  final double carbs; // g
  final double fat; // g
  final double fiber; // g（膳食纖維）
  final double sodium; // mg

  Nutrients operator +(Nutrients o) => Nutrients(
        protein: protein + o.protein,
        carbs: carbs + o.carbs,
        fat: fat + o.fat,
        fiber: fiber + o.fiber,
        sodium: sodium + o.sodium,
      );

  /// 乘上份數，例如 1.5 份
  Nutrients scale(double k) => Nutrients(
        protein: protein * k,
        carbs: carbs * k,
        fat: fat * k,
        fiber: fiber * k,
        sodium: sodium * k,
      );

  Map<String, double> toMap() => {
        'protein': protein,
        'carbs': carbs,
        'fat': fat,
        'fiber': fiber,
        'sodium': sodium,
      };

  /// 舊資料可能沒有某些欄位（或為 null），一律當 0
  factory Nutrients.fromMap(Map<String, Object?> map) {
    double d(String key) => (map[key] as num?)?.toDouble() ?? 0;
    return Nutrients(
      protein: d('protein'),
      carbs: d('carbs'),
      fat: d('fat'),
      fiber: d('fiber'),
      sodium: d('sodium'),
    );
  }
}
