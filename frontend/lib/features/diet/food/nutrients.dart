/// 熱量以外的營養素（熱量另外用 int 存，沿用既有的程式）。
/// 用在三個地方：餐點庫的一份食物、一筆飲食紀錄（已乘上份數）、統計頁的每日加總。
/// 欄位名稱跟 foods / meal_foods 表的欄位一致，toMap / fromMap 可以直接對 DB。
class Nutrients {
  // const 建構子：讓 Nutrients 可以當成編譯時常數(下面的 zero 要用到)
  const Nutrients({
    this.protein = 0,
    this.carbs = 0,
    this.fat = 0,
    this.fiber = 0,
    this.sodium = 0,
  });

  /// 全部都是 0 的營養素(相當於 Java 的 public static final Nutrients ZERO)
  static const Nutrients zero = Nutrients();

  final double protein; // g
  final double carbs; // g
  final double fat; // g
  final double fiber; // g（膳食纖維）
  final double sodium; // mg

  /// 兩份營養素相加，例如 a + b
  /// operator +：讓 Nutrients 可以用 + 號(Java 沒有這功能，相當於寫一個 add(other) 方法)
  Nutrients operator +(Nutrients other) {
    return Nutrients(
      protein: protein + other.protein,
      carbs: carbs + other.carbs,
      fat: fat + other.fat,
      fiber: fiber + other.fiber,
      sodium: sodium + other.sodium,
    );
  }

  /// 乘上份數，例如 1.5 份
  Nutrients scale(double factor) {
    return Nutrients(
      protein: protein * factor,
      carbs: carbs * factor,
      fat: fat * factor,
      fiber: fiber * factor,
      sodium: sodium * factor,
    );
  }

  /// 物件 → Map(存進資料庫用)
  Map<String, double> toMap() {
    final Map<String, double> map = <String, double>{
      'protein': protein,
      'carbs': carbs,
      'fat': fat,
      'fiber': fiber,
      'sodium': sodium,
    };
    return map;
  }

  /// 從 Map 取出一個營養素；沒有這個欄位或是 null 都當 0
  static double _readOrZero(Map<String, Object?> map, String key) {
    final Object? value = map[key];
    if (value == null) {
      return 0;
    }
    final num number = value as num;
    return number.toDouble();
  }

  /// Map → 物件。舊資料可能沒有某些欄位（或為 null），一律當 0
  factory Nutrients.fromMap(Map<String, Object?> map) {
    return Nutrients(
      protein: _readOrZero(map, 'protein'),
      carbs: _readOrZero(map, 'carbs'),
      fat: _readOrZero(map, 'fat'),
      fiber: _readOrZero(map, 'fiber'),
      sodium: _readOrZero(map, 'sodium'),
    );
  }
}
