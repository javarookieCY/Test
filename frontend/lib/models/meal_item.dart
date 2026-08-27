class MealFoodRecord {
  MealFoodRecord({required this.name, required this.calories, required this.portion});
  String name;
  int calories;
  double portion;
}

class MealItem {
  MealItem({required this.title, this.calories = 0, List<MealFoodRecord>? items})
      : items = items ?? [];
  final String title;
  int calories;
  List<MealFoodRecord> items;
}

// 從餐點庫選了某個食物、或手動輸入後，都會呼叫這個 callback
typedef MealFoodAdded = void Function(
  String mealTitle,
  String foodName,
  int calories,
  double portion,
);
