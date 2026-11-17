import 'nutrients.dart';

/// 某一餐裡的一樣食物(畫面顯示用)
class MealFoodRecord {
  MealFoodRecord({
    required this.name,
    required this.calories,
    required this.portion,
  });

  String name;
  int calories;
  double portion; // 份量倍數
}

/*
代表早餐、午餐、晚餐:
1.需要餐點名稱
2.預設卡路里為0
    如果有傳卡路里就用餐點的卡路里
3.傳入的items(食物紀錄陣列)可能為null
    如果有傳入items就當作本身的items
    如果沒有就開一個空陣列
*/
class MealItem {
  // 冒號後面是「初始化列表」：在建構子內容執行之前，先設定欄位的值
  // (Dart 規定 final 或非 null 的欄位要在這裡設定，Java 則是寫在建構子裡)
  MealItem({
    required this.title,
    this.calories = 0,
    List<MealFoodRecord>? items,
  }) : items = _itemsOrEmpty(items);

  final String title;
  int calories;
  List<MealFoodRecord> items;

  /// 有傳入 items 就用它，沒有(null)就開一個空清單
  static List<MealFoodRecord> _itemsOrEmpty(List<MealFoodRecord>? items) {
    if (items == null) {
      return <MealFoodRecord>[];
    }
    return items;
  }
}

/// 某一餐加入 / 修改一樣食物時的回呼函式的型別；nutrients 是已乘上份數的總量。
/// typedef：替一種函式型別取名字(相當於 Java 只有一個方法的 interface)
typedef MealFoodAdded = void Function(
  String mealTitle,
  String foodName,
  int calories,
  double portion,
  Nutrients nutrients,
);
