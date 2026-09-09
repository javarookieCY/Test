class MealFoodRecord {
  MealFoodRecord({required this.name, required this.calories, required this.portion});
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
  MealItem({required this.title, this.calories = 0, List<MealFoodRecord>? items})
      : items = items ?? [];
  final String title;
  int calories;
  List<MealFoodRecord> items;
}

// 
typedef MealFoodAdded = void Function(
  String mealTitle,
  String foodName,
  int calories,
  double portion,
);
