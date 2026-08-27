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
