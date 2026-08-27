import 'package:flutter/material.dart';

import '../db_helper.dart';
import '../models/food_item.dart';
import '../models/meal_item.dart';
import '../models/plan_item.dart';
import '../utils/constants.dart';
import '../widgets/home/calories_info.dart';
import '../widgets/home/home_header.dart';
import '../widgets/home/streak_section.dart';
import '../widgets/home/week_row.dart';
import '../widgets/meals/meal_entry.dart';

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});
  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  late final DateTime _today;
  late final List<DateTime> _weekDates;
  late int _selectedIndex;
  int _streakCount = 0;
  DateTime? _lastLoggedDate;

  // 使用者自訂的餐點庫（水煮蛋、地瓜...），從 SQLite 讀出來存在這裡
  List<FoodItem> _foodLibrary = [];

  final List<MealItem> _mealItems = [
    MealItem(title: '早餐'),
    MealItem(title: '午餐'),
    MealItem(title: '晚餐'),
    MealItem(title: '宵夜'),
    MealItem(title: '其他餐點'),
  ];
  static const int _dailyCalorieBudget = 3200;

  int get _consumedCalories =>
      _mealItems.fold(0, (sum, meal) => sum + meal.calories);

  int get _remainingCalories => _dailyCalorieBudget - _consumedCalories;

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  bool _isYesterday(DateTime a, DateTime b) {
    final yesterday = DateTime(b.year, b.month, b.day - 1);
    return _isSameDay(a, yesterday);
  }

  // 從餐點卡片選了一項食物（或手動輸入）後呼叫：
  // 熱量用「累加」的（一餐可能吃好幾樣東西），並記錄品項名稱，同時寫入 SQLite
  void _onFoodAddedToMeal(String mealTitle, String foodName, int calories, double portion) async {
    final meal = _mealItems.firstWhere((item) => item.title == mealTitle);
    final existingIdx = meal.items.indexWhere((e) => e.name == foodName);
    int calorieDiff = calories;

    if (existingIdx != -1) {
      calorieDiff = calories - meal.items[existingIdx].calories;
    }

    final date = _weekDates[_selectedIndex];
    final dateStr = '${date.year}-${date.month}-${date.day}';

    if (calorieDiff != 0) {
      await DBHelper.instance.insertMeal(mealTitle, calorieDiff, dateStr);
    }

    if (portion <= 0) {
      await DBHelper.instance.deleteMealFood(dateStr, mealTitle, foodName);
    } else {
      await DBHelper.instance.upsertMealFood(dateStr, mealTitle, foodName, calories, portion);
    }

    setState(() {
      if (existingIdx != -1) {
        if (portion <= 0) {
          meal.items.removeAt(existingIdx);
        } else {
          meal.items[existingIdx].portion = portion;
          meal.items[existingIdx].calories = calories;
        }
      } else {
        if (portion > 0) {
          meal.items.add(MealFoodRecord(name: foodName, calories: calories, portion: portion));
        }
      }
      meal.calories += calorieDiff;

      if (calorieDiff <= 0) return;

      final today = DateTime(
        DateTime.now().year,
        DateTime.now().month,
        DateTime.now().day,
      );

      if (_lastLoggedDate == null) {
        _streakCount = 1;
        _lastLoggedDate = today;
      } else if (_isSameDay(_lastLoggedDate!, today)) {
        // 同一天，不加
      } else if (_isYesterday(_lastLoggedDate!, today)) {
        _streakCount += 1;
        _lastLoggedDate = today;
      } else {
        _streakCount = 1;
        _lastLoggedDate = today;
      }
    });
  }

  // 從 SQLite 讀出目前的餐點庫，更新畫面
  Future<void> _loadFoodLibrary() async {
    final foods = await DBHelper.instance.getAllFoods();
    setState(() => _foodLibrary = foods);
  }

  // 從 SQLite 讀取指定日期的所有餐點明細
  Future<void> _loadMealsForDate(DateTime date) async {
    final dateStr = '${date.year}-${date.month}-${date.day}';
    final mealFoods = await DBHelper.instance.getMealFoodsByDate(dateStr);
    
    setState(() {
      for (var meal in _mealItems) {
        meal.calories = 0;
        meal.items.clear();
      }

      for (var row in mealFoods) {
        final mealTitle = row['meal_title'] as String;
        final foodName = row['food_name'] as String;
        final calories = row['calories'] as int;
        final portion = (row['portion'] as num).toDouble();

        final mealIdx = _mealItems.indexWhere((item) => item.title == mealTitle);
        if (mealIdx != -1) {
          _mealItems[mealIdx].items.add(
            MealFoodRecord(name: foodName, calories: calories, portion: portion)
          );
          _mealItems[mealIdx].calories += calories;
        }
      }
    });
  }

  // 使用者在「新增餐點」表單按下確認時呼叫：寫入 SQLite，再重新整理列表
  // 回傳 true 代表存成功，false 代表存失敗（讓呼叫端知道要不要關對話框）
  Future<bool> _addFoodToLibrary(FoodItem food) async {
    try {
      await DBHelper.instance.insertFood(food);
      await _loadFoodLibrary();
      return true;
    } catch (e) {
      debugPrint('新增餐點失敗: $e'); // 印在 debug console，方便你自己抓錯
      return false;
    }
  }

  Future<bool> _updateFoodInLibrary(FoodItem food) async {
    try {
      await DBHelper.instance.updateFood(food);
      await _loadFoodLibrary();
      return true;
    } catch (e) {
      debugPrint('修改餐點失敗: $e');
      return false;
    }
  }

  // 從餐點庫刪除一項食物範本
  Future<void> _deleteFoodFromLibrary(int id) async {
    await DBHelper.instance.deleteFood(id);
    await _loadFoodLibrary();
  }

  // 彈出「新增/修改餐點」表單：輸入名稱、熱量、蛋白質、碳水、脂肪
  void _showAddFoodDialog({FoodItem? foodToEdit}) {
    final isEdit = foodToEdit != null;
    final nameController = TextEditingController(text: foodToEdit?.name ?? '');
    final caloriesController = TextEditingController(text: foodToEdit?.calories.toString() ?? '');
    final proteinController = TextEditingController(text: isEdit && foodToEdit.protein > 0 ? foodToEdit.protein.toString() : '');
    final carbsController = TextEditingController(text: isEdit && foodToEdit.carbs > 0 ? foodToEdit.carbs.toString() : '');
    final fatController = TextEditingController(text: isEdit && foodToEdit.fat > 0 ? foodToEdit.fat.toString() : '');

    showDialog(
      context: context,
      builder: (dialogContext) {
        // 用 StatefulBuilder 讓對話框內部能自己 setState 顯示錯誤訊息，
        // 不用把整個 _MyHomePageState 都 rebuild
        String? errorText;
        bool isSaving = false;

        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              title: Text(isEdit ? '修改餐點' : '新增餐點'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(labelText: '名稱（例如：水煮蛋）'),
                    ),
                    TextField(
                      controller: caloriesController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: '熱量 (kcal) *必填'),
                    ),
                    TextField(
                      controller: proteinController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: '蛋白質 (g)，可留空'),
                    ),
                    TextField(
                      controller: carbsController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: '碳水化合物 (g)，可留空'),
                    ),
                    TextField(
                      controller: fatController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: '脂肪 (g)，可留空'),
                    ),
                    if (errorText != null) ...[
                      const SizedBox(height: 8),
                      Text(errorText!, style: const TextStyle(color: Colors.red)),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSaving ? null : () => Navigator.pop(dialogContext),
                  child: const Text('取消'),
                ),
                ElevatedButton(
                  onPressed: isSaving
                      ? null
                      : () async {
                          final name = nameController.text.trim();
                          final calories = int.tryParse(caloriesController.text.trim());

                          // 驗證失敗：直接把原因顯示在對話框裡，不要默默 return
                          if (name.isEmpty) {
                            setDialogState(() => errorText = '請輸入名稱');
                            return;
                          }
                          if (calories == null) {
                            setDialogState(() => errorText = '熱量請輸入數字');
                            return;
                          }

                          setDialogState(() {
                            errorText = null;
                            isSaving = true;
                          });

                          final food = FoodItem(
                            id: isEdit ? foodToEdit.id : null,
                            name: name,
                            calories: calories,
                            protein: double.tryParse(proteinController.text.trim()) ?? 0,
                            carbs: double.tryParse(carbsController.text.trim()) ?? 0,
                            fat: double.tryParse(fatController.text.trim()) ?? 0,
                          );

                          final success = isEdit ? await _updateFoodInLibrary(food) : await _addFoodToLibrary(food);

                          if (!dialogContext.mounted) return;

                          if (success) {
                            Navigator.pop(dialogContext);
                            // ignore: use_build_context_synchronously
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(isEdit ? '已修改「$name」' : '已新增「$name」')),
                            );
                          } else {
                            setDialogState(() {
                              isSaving = false;
                              errorText = '儲存失敗，請稍後再試';
                            });
                          }
                        },
                  child: isSaving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('儲存'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // 彈出「管理餐點庫」列表：可以看目前有哪些餐點、刪除、或新增
  void _showManageFoodLibraryDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('我的餐點'),
          content: SizedBox(
            width: double.maxFinite,
            child: _foodLibrary.isEmpty
                ? const Text('目前還沒有任何餐點，點下方「新增」開始建立吧！')
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: _foodLibrary.length,
                    itemBuilder: (context, index) {
                      final food = _foodLibrary[index];
                      return ListTile(
                        title: Text(food.name),
                        subtitle: Text('${food.calories} kcal'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit, color: Colors.blue),
                              onPressed: () {
                                Navigator.pop(context);
                                _showAddFoodDialog(foodToEdit: food);
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () async {
                                await _deleteFoodFromLibrary(food.id!);
                                setDialogState(() {});
                              },
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('關閉'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _showAddFoodDialog();
              },
              child: const Text('新增'),
            ),
          ],
        );
          },
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _today = DateTime(now.year, now.month, now.day);
    final monday = _today.subtract(Duration(days: _today.weekday - 1));
    _weekDates = List.generate(7, (i) => monday.add(Duration(days: i)));
    _selectedIndex = _today.weekday - 1;
    _loadFoodLibrary(); // App 一開啟就先把餐點庫讀出來
    _loadMealsForDate(_weekDates[_selectedIndex]); // 載入今天的餐點紀錄
  }

  String get _selectedDateLabel {
    final date = _weekDates[_selectedIndex];
    final diff = date.difference(_today).inDays;
    if (diff == 0) return '今天';
    if (diff == -1) return '昨天';
    if (diff == 1) return '明天';
    return '${date.month}/${date.day}';
  }

  void _selectDay(int index) {
    setState(() => _selectedIndex = index);
    _loadMealsForDate(_weekDates[index]);
  }

    final List<PlanItem> _samplePlans = const [
    PlanItem(
      title: '低碳方案',
      imagePath: 'assets/images/plan_low_carb.jpg',
      description: '減少精緻澱粉攝取，以蛋白質與蔬菜為主的飲食方式。',
      dietRules: ['每日碳水控制在100g以內', '優先選擇原型食物', '避免含糖飲料'],
    ),
    PlanItem(
      title: '地中海方案',
      imagePath: 'assets/images/plan_mediterranean.jpg',
      description: '以橄欖油、魚類、蔬果為主，強調不飽和脂肪。',
      dietRules: ['每週至少2次魚類', '多攝取堅果與豆類', '減少紅肉頻率'],
    ),
    PlanItem(
      title: '高蛋白方案',
      imagePath: 'assets/images/plan_high_protein.jpg',
      description: '提高蛋白質比例，適合有重訓習慣的人。',
      dietRules: ['每公斤體重攝取1.6-2.2g蛋白質', '分散在三餐攝取', '搭配足夠水分'],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        alignment: Alignment.center,
        color: ElementColors.background,
        child: Column(
          children: [
            Expanded(
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Column(
                      children: [
                        HomeHeader(dateLabel: _selectedDateLabel),
                        WeekRow(
                          today: _today,
                          weekDates: _weekDates,
                          selectedIndex: _selectedIndex,
                          onSelect: _selectDay,
                        ),
                        const SizedBox(height: 15.0),
                        StreakInfoRow(streakCount: _streakCount),
                        const SizedBox(height: 15.0),
                        FoodStreakSection(plans: _samplePlans),
                        CaloriesFetch(
                          remaining: _remainingCalories,
                          consumed: _consumedCalories,
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 15.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton.icon(
                                onPressed: _showManageFoodLibraryDialog,
                                icon: const Icon(Icons.list_alt, color: Colors.white),
                                label: const Text(
                                  '管理餐點庫',
                                  style: TextStyle(color: Colors.white),
                                ),
                              ),
                            ],
                          ),
                        ),
                        MealEntry(
                          meals: _mealItems,
                          foodLibrary: _foodLibrary,
                          onFoodAdded: _onFoodAddedToMeal,
                          onManageFoodLibrary: _showAddFoodDialog,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
