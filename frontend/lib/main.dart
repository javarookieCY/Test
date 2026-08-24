import 'dart:ui';
import 'db_helper.dart';
import 'package:device_preview/device_preview.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(
    DevicePreview(
      enabled: true,
      builder: (context) => const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      locale: DevicePreview.locale(context),
      builder: DevicePreview.appBuilder,
      scrollBehavior: MyScrollBehavior(),
      title: 'Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const MyHomePage(title: 'Demo'),
    );
  }
}

// - 常用顏色 -
class ElementColors {
  static const background = Color.fromARGB(255, 30, 30, 32);
  static const dayBg = Color.fromARGB(100, 116, 116, 116);
  static const dayBorder = Color.fromARGB(255, 179, 179, 179);
}
// - 常用字體 -
const kGreyBoldText = TextStyle(color: Colors.grey, fontWeight: FontWeight.bold);
const kTitleText = TextStyle(
  color: Colors.white,
  fontSize: 18.0,
  fontWeight: FontWeight.w600,
  letterSpacing: 2,
);

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
    final imagePathController = TextEditingController(text: foodToEdit?.imagePath ?? '');
    final descriptionController = TextEditingController(text: foodToEdit?.description ?? '');

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
                    const SizedBox(height: 8),
                    TextField(
                      controller: imagePathController,
                      decoration: const InputDecoration(
                        labelText: '圖片路徑，可留空',
                        hintText: 'assets/images/foods/my_food.jpg',
                      ),
                    ),
                    TextField(
                      controller: descriptionController,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: '內容物說明，可留空',
                        hintText: '例如：雞胸肉 150g、糙米飯 1碗、水煮蛋 1顆',
                      ),
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

                          final imagePathText = imagePathController.text.trim();
                          final descriptionText = descriptionController.text.trim();

                          final food = FoodItem(
                            id: isEdit ? foodToEdit.id : null,
                            name: name,
                            calories: calories,
                            protein: double.tryParse(proteinController.text.trim()) ?? 0,
                            carbs: double.tryParse(carbsController.text.trim()) ?? 0,
                            fat: double.tryParse(fatController.text.trim()) ?? 0,
                            imagePath: imagePathText.isEmpty ? null : imagePathText,
                            description: descriptionText.isEmpty ? null : descriptionText,
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
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _showPresetMealPicker();
              },
              child: const Text('選擇預設餐點'),
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

  // 彈出「預設餐點」卡片牆：從螢幕底部滑出，內建範本 + 使用者自己有配圖的自訂餐點
  // 都用同樣的卡片呈現，點卡片看詳情，內建範本可以一鍵加進自己的餐點庫
  void _showPresetMealPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _PresetMealSheet(
        presets: kPresetMeals,
        customFoods: _foodLibrary.where((f) => (f.imagePath ?? '').isNotEmpty).toList(),
        onAddPreset: _addPresetMealToLibrary,
        onEditCustomFood: (food) {
          Navigator.pop(context);
          _showAddFoodDialog(foodToEdit: food);
        },
      ),
    );
  }

  // 把一個內建範本「加入我的餐點庫」：轉成 FoodItem 寫進 SQLite
  Future<void> _addPresetMealToLibrary(PresetMeal preset) async {
    final alreadyExists = _foodLibrary.any((f) => f.name == preset.name);
    if (alreadyExists) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('「${preset.name}」已經在你的餐點庫囉')),
      );
      return;
    }

    final food = FoodItem(
      name: preset.name,
      calories: preset.calories,
      protein: preset.protein,
      carbs: preset.carbs,
      fat: preset.fat,
      imagePath: preset.imagePath,
      description: preset.ingredients.join('、'),
    );

    final success = await _addFoodToLibrary(food);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(success ? '已加入「${preset.name}」' : '加入失敗，請稍後再試')),
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
                        _HomeHeader(dateLabel: _selectedDateLabel),
                        _WeekRow(
                          today: _today,
                          weekDates: _weekDates,
                          selectedIndex: _selectedIndex,
                          onSelect: _selectDay,
                        ),
                        const SizedBox(height: 15.0),
                        _StreakInfoRow(streakCount: _streakCount),
                        const SizedBox(height: 15.0),
                        FoodStreakSection(plans: _samplePlans),
                        _CaloriesFetch(
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

// - 頁首 -
class _HomeHeader extends StatelessWidget {
  const _HomeHeader({required this.dateLabel});
  final String dateLabel;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 47.0, width: double.infinity),
        Row(
          children: [
            const SizedBox(width: 15.0),
            ElevatedButton(
              onPressed: () {},
              child: const Icon(Icons.notification_add),
            ),
          ],
        ),
        Padding(
          padding: EdgeInsets.all(15.0),
          child: Row(
            children: [Text(dateLabel, style: kTitleText)],
          ),
        ),
      ],
    );
  }
}

// - 一週 -
class _WeekRow extends StatelessWidget {

  const _WeekRow({
    required this.today,
    required this.weekDates,
    required this.selectedIndex,
    required this.onSelect,
  });

  final DateTime today;
  final List<DateTime> weekDates;
  final int selectedIndex;
  final ValueChanged<int> onSelect;

  static const _dayLabels = ['一', '二', '三', '四', '五', '六', '日'];

  Color _fillColor({required bool isToday, required bool isSelected, required bool isPast}) {
    if (isSelected && isToday) return Colors.green;
    if (isToday) return Colors.grey.shade300;
    if (isPast) return Colors.grey.shade800;
    return ElementColors.background;
  }

 @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: List.generate(7, (index) {
        final date = weekDates[index];
        final isToday = date == today;
        final isSelected = index == selectedIndex;
        final isPast = date.isBefore(today);

        return GestureDetector(
          onTap: () => onSelect(index),
          child: Column(
            children: [
              Container(
                height: 30,
                width: 30,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _fillColor(isToday: isToday, isSelected: isSelected, isPast: isPast),
                  border: Border.all(
                    color: isSelected ? Colors.green : const Color.fromARGB(255, 87, 85, 85),
                    width: 2.0,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(_dayLabels[index], style: const TextStyle(color: Colors.grey)),
            ],
          ),
        );
      }),
    );
  }
}

// - 連續紀錄 -
class _StreakInfoRow extends StatelessWidget {
  const _StreakInfoRow({required this.streakCount});

  final int streakCount;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const SizedBox(width: 15.0),
        Text('$streakCount', style: kGreyBoldText),
        const SizedBox(width: 2.0),
        const Icon(Icons.done, color: Colors.grey),
        const SizedBox(width: 15.0),
        Text(
          streakCount > 0 ? '天連續記錄' : '記錄食物來開始連續紀錄',
          style: kGreyBoldText,
        ),
      ],
    );
  }
}

// - 飲食計畫 -
class FoodStreakSection extends StatefulWidget {
  const FoodStreakSection({super.key, required this.plans});
  final List<PlanItem> plans;
  @override
  State<FoodStreakSection> createState() => _FoodStreakSectionState();
}
class _FoodStreakSectionState extends State<FoodStreakSection> {
  bool _isExpanded = false;
  
  @override
  Widget build(BuildContext context) {
    double containerHeight;
    Widget buttonLook;

    if(_isExpanded == true){
      containerHeight = 120.0;
      buttonLook = const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.explore,
              color: Colors.white,
          ),
          SizedBox(width: 6.0,),
          Text('探索計畫',
            style: TextStyle(
              color: Colors.white,
            ),
          ),
        ],
      );
    }
    else{
      containerHeight = 0.0;
      buttonLook = const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.expand_more,
              color: Colors.white,
            ),
          SizedBox(width: 6.0,),
          Text('展開',
            style: TextStyle(
              color: Colors.white,
            ),
          ),
        ]
      );
    }

    return Column(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: containerHeight,
          width: double.infinity,
          margin: const EdgeInsets.symmetric(horizontal: 15.0),
          decoration: BoxDecoration(
            color: ElementColors.dayBg,
            borderRadius: BorderRadius.circular(8.0),
          ),
          child: containerHeight > 0
              ? _PlanCarousel(plans: widget.plans)
              : null, // 收起時高度是0，不需要塞內容
        ),
        const SizedBox(height: 8.0),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
              ),
              onPressed: () => setState(() => _isExpanded = !_isExpanded),
              child: buttonLook,
            ),
            const SizedBox(width: 15.0),
          ],
        ),
      ],
    );
  }
}

// - 熱量攝取 -
class _CaloriesFetch extends StatelessWidget {
  const _CaloriesFetch({
    required this.remaining,
    required this.consumed,
  });

  final int remaining;
  final int consumed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(15.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _CaloriesRow(label: '剩餘熱量', value: '$remaining kcal'),
          const SizedBox(height: 5.0),
          _CaloriesRow(label: '已攝取熱量', value: '$consumed kcal'),
        ],
      ),
    );
  }
}
class _CaloriesRow extends StatelessWidget{
  const _CaloriesRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: Colors.white),),
        Text(value, style: TextStyle(color: Colors.white),),
      ],
    );
  } 
}

// - 上傳食物 -
class MealEntry extends StatelessWidget {
  const MealEntry({
    super.key,
    required this.meals,
    required this.foodLibrary,
    required this.onFoodAdded,
    required this.onManageFoodLibrary,
  });

  final List<MealItem> meals;
  final List<FoodItem> foodLibrary;
  final MealFoodAdded onFoodAdded;
  final VoidCallback onManageFoodLibrary;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: meals
          .map(
            (meal) => MealCard(
              title: meal.title,
              calories: meal.calories,
              items: meal.items,
              foodLibrary: foodLibrary,
              onManageFoodLibrary: onManageFoodLibrary,
              onFoodSelected: (foodName, calories, portion) =>
                  onFoodAdded(meal.title, foodName, calories, portion),
            ),
          )
          .toList(),
    );
  }
}

class MealCard extends StatefulWidget {
  const MealCard({
    super.key,
    required this.title,
    required this.calories,
    required this.items,
    required this.foodLibrary,
    required this.onFoodSelected,
    required this.onManageFoodLibrary,
  });

  final String title;
  final int calories;
  final List<MealFoodRecord> items;
  final List<FoodItem> foodLibrary;
  // 選好食物後回傳 (foodName, calories, portion)
  final void Function(String foodName, int calories, double portion) onFoodSelected;
  final VoidCallback onManageFoodLibrary;

  @override
  State<MealCard> createState() => _MealCardState();
}

class _MealCardState extends State<MealCard> {
  final TextEditingController _manualNameController = TextEditingController();
  final TextEditingController _manualCaloriesController = TextEditingController();

  IconData _iconForTitle(String title) {
    switch (title) {
      case '早餐':
        return Icons.wb_sunny;
      case '午餐':
        return Icons.lunch_dining;
      case '晚餐':
        return Icons.nights_stay;
      case '宵夜':
        return Icons.bedtime;
      default:
        return Icons.fastfood;
    }
  }

  // 手動輸入一次性的熱量（餐點庫沒有的東西，臨時吃了一次）
  void _showManualEntryDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('${widget.title} 手動輸入'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _manualNameController,
                decoration: const InputDecoration(hintText: '名稱（可留空）'),
              ),
              TextField(
                controller: _manualCaloriesController,
                keyboardType: TextInputType.number,
                autofocus: true,
                decoration: const InputDecoration(hintText: '輸入熱量 (kcal)'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () {
                final value = int.tryParse(_manualCaloriesController.text);
                if (value != null) {
                  final name = _manualNameController.text.trim();
                  widget.onFoodSelected(name.isEmpty ? '自訂' : name, value, 1.0);
                  _manualNameController.clear();
                  _manualCaloriesController.clear();
                }
                Navigator.pop(context);
              },
              child: const Text('確認'),
            ),
          ],
        );
      },
    );
  }

  void _showPortionDialog(FoodItem food) {
    final existingIdx = widget.items.indexWhere((e) => e.name == food.name);
    double portion = existingIdx != -1 ? widget.items[existingIdx].portion : 1.0;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              title: Text('選擇份數 - ${food.name}'),
              content: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    onPressed: portion > 0
                        ? () => setDialogState(() => portion -= 0.5)
                        : null,
                    icon: const Icon(Icons.remove),
                  ),
                  Text('$portion 份', style: const TextStyle(fontSize: 18)),
                  IconButton(
                    onPressed: () => setDialogState(() => portion += 0.5),
                    icon: const Icon(Icons.add),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('取消'),
                ),
                ElevatedButton(
                  onPressed: () {
                    final totalCalories = (food.calories * portion).round();
                    widget.onFoodSelected(food.name, totalCalories, portion);
                    Navigator.pop(dialogContext);
                  },
                  child: const Text('確認'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // 按下「+」時：跳出餐點庫選單，讓使用者挑選要吃的東西
  void _showFoodPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color.fromARGB(255, 40, 40, 42),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('${widget.title} - 選擇餐點',
                    style: const TextStyle(
                        color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                if (widget.foodLibrary.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20.0),
                    child: Text(
                      '餐點庫還是空的，先新增幾樣常吃的食物吧！',
                      style: const TextStyle(color: Colors.white70),
                      textAlign: TextAlign.center,
                    ),
                  )
                else
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 300),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: widget.foodLibrary.length,
                      itemBuilder: (context, index) {
                        final food = widget.foodLibrary[index];
                        return Card(
                          color: ElementColors.dayBg,
                          child: ListTile(
                            title: Text(food.name,
                                style: const TextStyle(color: Colors.white)),
                            subtitle: Text(
                              '${food.calories} kcal ・ 蛋白質 ${food.protein}g',
                              style: const TextStyle(color: Colors.white70),
                            ),
                            onTap: () {
                              Navigator.pop(context); // 先關閉 bottom sheet
                              _showPortionDialog(food); // 彈出選擇份數
                            },
                          ),
                        );
                      },
                    ),
                  ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          widget.onManageFoodLibrary();
                        },
                        icon: const Icon(Icons.add, color: Colors.green),
                        label: const Text('新增餐點', style: TextStyle(color: Colors.green)),
                      ),
                    ),
                    Expanded(
                      child: TextButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          _showManualEntryDialog();
                        },
                        icon: const Icon(Icons.edit, color: Colors.white70),
                        label: const Text('手動輸入', style: TextStyle(color: Colors.white70)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final iconData = _iconForTitle(widget.title);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 15.0, vertical: 6.0),
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      decoration: BoxDecoration(
        color: ElementColors.dayBg,
        borderRadius: BorderRadius.circular(8.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const SizedBox(width: 12.0),
              Icon(iconData, color: Colors.white),
              const SizedBox(width: 8.0),
              Text(
                widget.title,
                style: const TextStyle(color: Colors.white),
              ),
              const Spacer(),
              if (widget.calories > 0)
                Text(
                  '${widget.calories} kcal',
                  style: const TextStyle(color: Colors.white),
                ),
              if (widget.calories > 0) const SizedBox(width: 8.0),
              IconButton(
                onPressed: _showFoodPicker,
                icon: const Icon(Icons.add, color: Colors.green),
              ),
              const SizedBox(width: 12.0),
            ],
          ),
          // 顯示這一餐目前已經加入的品項，例如：水煮蛋、地瓜
          if (widget.items.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 48.0, right: 12.0, top: 2.0),
              child: Text(
                widget.items.map((e) {
                  String pStr = e.portion == e.portion.toInt()
                      ? e.portion.toInt().toString()
                      : e.portion.toString();
                  return e.portion == 1.0 ? e.name : '${e.name} (x$pStr)';
                }).join('、'),
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }
}


// - 食物 -
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

// - 預設餐點卡片的資料模型 -
// 跟 FoodItem 不同：PresetMeal 是寫死在 App 裡的範本，使用者按「加入我的餐點庫」
// 之後才會真的變成一筆 FoodItem 存進 SQLite
class PresetMeal {
  const PresetMeal({
    required this.name,
    required this.imagePath,
    required this.calories,
    this.protein = 0,
    this.carbs = 0,
    this.fat = 0,
    required this.ingredients,
  });

  final String name;
  final String imagePath; // asset 圖片路徑，需自行放圖到 assets/images/foods/ 底下
  final int calories;
  final double protein;
  final double carbs;
  final double fat;
  final List<String> ingredients; // 內容物清單，例如：['大麥克 1份', '可樂(中) 1杯', '中薯 1份']
}

// 8 個範例預設餐點：4 個常見速食套餐 + 4 個健身/健康餐盒
const List<PresetMeal> kPresetMeals = [
  PresetMeal(
    name: '大麥克套餐',
    imagePath: 'assets/images/foods/mcdonalds_bigmac_meal.jpg',
    calories: 860,
    protein: 27,
    carbs: 103,
    fat: 37,
    ingredients: ['大麥克 1份', '中薯 1份', '可樂(中) 1杯'],
  ),
  PresetMeal(
    name: '麥克雞塊套餐（10塊）',
    imagePath: 'assets/images/foods/mcdonalds_nuggets_meal.jpg',
    calories: 780,
    protein: 30,
    carbs: 95,
    fat: 32,
    ingredients: ['麥克雞塊 10塊', '中薯 1份', '可樂(中) 1杯'],
  ),
  PresetMeal(
    name: '勁辣雞腿堡套餐',
    imagePath: 'assets/images/foods/mcdonalds_spicy_chicken_meal.jpg',
    calories: 900,
    protein: 32,
    carbs: 98,
    fat: 42,
    ingredients: ['勁辣雞腿堡 1份', '中薯 1份', '可樂(中) 1杯'],
  ),
  PresetMeal(
    name: '雙層牛肉吉事堡套餐',
    imagePath: 'assets/images/foods/mcdonalds_double_cheeseburger_meal.jpg',
    calories: 920,
    protein: 35,
    carbs: 90,
    fat: 46,
    ingredients: ['雙層牛肉吉事堡 1份', '中薯 1份', '可樂(中) 1杯'],
  ),
  PresetMeal(
    name: '雞胸肉健身餐盒',
    imagePath: 'assets/images/foods/chicken_breast_fit_box.jpg',
    calories: 420,
    protein: 45,
    carbs: 40,
    fat: 8,
    ingredients: ['舒肥雞胸肉 150g', '糙米飯 150g', '花椰菜 100g'],
  ),
  PresetMeal(
    name: '鮭魚藜麥碗',
    imagePath: 'assets/images/foods/salmon_quinoa_bowl.jpg',
    calories: 480,
    protein: 34,
    carbs: 45,
    fat: 18,
    ingredients: ['香煎鮭魚 120g', '藜麥飯 150g', '綜合生菜 100g', '橄欖油醬汁'],
  ),
  PresetMeal(
    name: '地中海雞肉沙拉',
    imagePath: 'assets/images/foods/mediterranean_chicken_salad.jpg',
    calories: 390,
    protein: 32,
    carbs: 25,
    fat: 18,
    ingredients: ['烤雞胸肉 120g', '生菜與小番茄', '菲達起司 20g', '橄欖油醋汁'],
  ),
  PresetMeal(
    name: '牛肉蔬菜便當',
    imagePath: 'assets/images/foods/beef_veggie_bento.jpg',
    calories: 560,
    protein: 38,
    carbs: 55,
    fat: 20,
    ingredients: ['嫩煎牛肉片 130g', '十穀飯 150g', '炒時蔬 120g'],
  ),
];

class PlanItem {
  const PlanItem({
    required this.title,
    required this.imagePath,
    required this.description,
    required this.dietRules,
  });
  final String title;
  final String imagePath;
  final String description;
  final List<String> dietRules;
}

// - 方案飲食規範 -
class _PlanCarousel extends StatefulWidget {
  const _PlanCarousel({required this.plans});
  final List<PlanItem> plans;

   @override
  State<_PlanCarousel> createState() => _PlanCarouselState();
}
class _PlanCarouselState extends State<_PlanCarousel> {
  static const int _loopMultiplier = 10000; // 假裝很長的倍數

  late final PageController _controller;

  @override
  void initState() {
    super.initState();
    // 找一個中間值，且對 plans.length 取餘數要等於 1（對應圖2，index從0算）
    final middle = (widget.plans.length * _loopMultiplier) ~/ 2;
    final offsetToIndex1 = (1 - middle % widget.plans.length) % widget.plans.length;
    final initialPage = middle + offsetToIndex1;

    _controller = PageController(viewportFraction: 0.6, initialPage: initialPage);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PageView.builder(
      controller: _controller,
      itemCount: widget.plans.length * _loopMultiplier,
      itemBuilder: (context, rawIndex) {
        final index = rawIndex % widget.plans.length; // 換算回真正的資料
        final plan = widget.plans[index];
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6.0),
          child: GestureDetector(
            onTap: () => _showPlanDetail(context, plan),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8.0),
              child: Image.asset(plan.imagePath, fit: BoxFit.cover),
            ),
          ),
        );
      },
    );
  }

  void _showPlanDetail(BuildContext context, PlanItem plan) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _PlanDetailSheet(plan: plan),
    );
  }
}
class _PlanDetailSheet extends StatelessWidget {
  const _PlanDetailSheet({required this.plan});
  final PlanItem plan;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Color.fromARGB(255, 40, 40, 42),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.all(20.0),
          child: ListView(
            controller: scrollController, // 交給 DraggableScrollableSheet 控制，拖動跟捲動才不會打架
            children: [
              Text(plan.title,
                  style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Text(plan.description, style: const TextStyle(color: Colors.white70)),
              const SizedBox(height: 16),
              const Text('飲食規範', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              ...plan.dietRules.map((rule) => Padding(
                    padding: const EdgeInsets.only(bottom: 6.0),
                    child: Text('• $rule', style: const TextStyle(color: Colors.white70)),
                  )),
            ],
          ),
        );
      },
    );
  }
}

// - 預設餐點卡片牆 -
// 從「管理餐點庫」點「選擇預設餐點」後跳出，內建範本跟使用者自己有配圖的
// 自訂餐點會混在同一個格線裡，用同樣的卡片樣式呈現
class _PresetMealSheet extends StatelessWidget {
  const _PresetMealSheet({
    required this.presets,
    required this.customFoods,
    required this.onAddPreset,
    required this.onEditCustomFood,
  });

  final List<PresetMeal> presets;
  final List<FoodItem> customFoods;
  final ValueChanged<PresetMeal> onAddPreset;
  final ValueChanged<FoodItem> onEditCustomFood;

  void _openPresetDetail(BuildContext context, PresetMeal preset) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _PresetMealDetailSheet(
        preset: preset,
        onAdd: () {
          Navigator.pop(context); // 關詳情頁
          onAddPreset(preset);
        },
      ),
    );
  }

  void _openCustomDetail(BuildContext context, FoodItem food) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _CustomFoodDetailSheet(
        food: food,
        onEdit: () => onEditCustomFood(food),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final totalCount = presets.length + customFoods.length;

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.45,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Color.fromARGB(255, 40, 40, 42),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 14, 20, 4),
                child: Row(
                  children: [
                    Text('預設餐點',
                        style: TextStyle(
                            color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                    SizedBox(width: 8),
                    Text('點卡片看內容物與營養成分',
                        style: TextStyle(color: Colors.white54, fontSize: 12)),
                  ],
                ),
              ),
              Expanded(
                child: totalCount == 0
                    ? const Center(
                        child: Text('目前沒有可顯示的餐點', style: TextStyle(color: Colors.white54)),
                      )
                    : GridView.builder(
                        controller: scrollController,
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          childAspectRatio: 0.82,
                        ),
                        itemCount: totalCount,
                        itemBuilder: (context, index) {
                          if (index < presets.length) {
                            final preset = presets[index];
                            return _MealGridCard(
                              name: preset.name,
                              imagePath: preset.imagePath,
                              calories: preset.calories,
                              tag: '範本',
                              onTap: () => _openPresetDetail(context, preset),
                            );
                          }
                          final food = customFoods[index - presets.length];
                          return _MealGridCard(
                            name: food.name,
                            imagePath: food.imagePath!,
                            calories: food.calories,
                            tag: '我的',
                            onTap: () => _openCustomDetail(context, food),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// 卡片牆裡的單張卡片：圖片 + 品名 + 熱量 + 來源標籤（範本／我的）
class _MealGridCard extends StatelessWidget {
  const _MealGridCard({
    required this.name,
    required this.imagePath,
    required this.calories,
    required this.tag,
    required this.onTap,
  });

  final String name;
  final String imagePath;
  final int calories;
  final String tag;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Container(
          color: ElementColors.dayBg,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _FoodImage(imagePath: imagePath),
                    Positioned(
                      top: 6,
                      left: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(tag, style: const TextStyle(color: Colors.white, fontSize: 10)),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text('$calories kcal', style: const TextStyle(color: Colors.white54, fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// 圖片載入失敗（例如你還沒放圖進 assets）時，改顯示一個灰底 icon 佔位，不會讓 App 爆掉
class _FoodImage extends StatelessWidget {
  const _FoodImage({required this.imagePath});
  final String imagePath;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      imagePath,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => Container(
        color: Colors.white10,
        alignment: Alignment.center,
        child: const Icon(Icons.restaurant, color: Colors.white38, size: 32),
      ),
    );
  }
}

// 內建範本的詳情頁：大圖 + 熱量／三大營養素 + 內容物清單 + 「加入我的餐點庫」
class _PresetMealDetailSheet extends StatelessWidget {
  const _PresetMealDetailSheet({required this.preset, required this.onAdd});
  final PresetMeal preset;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Color.fromARGB(255, 40, 40, 42),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: ListView(
            controller: scrollController,
            padding: EdgeInsets.zero,
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: _FoodImage(imagePath: preset.imagePath),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(preset.name,
                        style: const TextStyle(
                            color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    _NutritionRow(preset: preset),
                    const SizedBox(height: 16),
                    const Text('內容物', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    ...preset.ingredients.map((item) => Padding(
                          padding: const EdgeInsets.only(bottom: 6.0),
                          child: Text('• $item', style: const TextStyle(color: Colors.white70)),
                        )),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: onAdd,
                        icon: const Icon(Icons.add),
                        label: const Text('加入我的餐點庫'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// 使用者自訂餐點的詳情頁：跟範本長得一樣，但按鈕換成「編輯」，因為它已經在餐點庫裡了
class _CustomFoodDetailSheet extends StatelessWidget {
  const _CustomFoodDetailSheet({required this.food, required this.onEdit});
  final FoodItem food;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final ingredients = (food.description ?? '')
        .split('、')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Color.fromARGB(255, 40, 40, 42),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: ListView(
            controller: scrollController,
            padding: EdgeInsets.zero,
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: _FoodImage(imagePath: food.imagePath!),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(food.name,
                        style: const TextStyle(
                            color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    _NutritionRow(
                      preset: PresetMeal(
                        name: food.name,
                        imagePath: food.imagePath!,
                        calories: food.calories,
                        protein: food.protein,
                        carbs: food.carbs,
                        fat: food.fat,
                        ingredients: ingredients,
                      ),
                    ),
                    if (ingredients.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      const Text('內容物', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      ...ingredients.map((item) => Padding(
                            padding: const EdgeInsets.only(bottom: 6.0),
                            child: Text('• $item', style: const TextStyle(color: Colors.white70)),
                          )),
                    ],
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: onEdit,
                        icon: const Icon(Icons.edit, color: Colors.white),
                        label: const Text('編輯這個餐點', style: TextStyle(color: Colors.white)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// 熱量／蛋白質／碳水／脂肪 四格顯示，詳情頁跟自訂餐點頁共用
class _NutritionRow extends StatelessWidget {
  const _NutritionRow({required this.preset});
  final PresetMeal preset;

  @override
  Widget build(BuildContext context) {
    Widget stat(String label, String value) {
      return Expanded(
        child: Column(
          children: [
            Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12)),
          ],
        ),
      );
    }

    return Row(
      children: [
        stat('熱量', '${preset.calories}'),
        stat('蛋白質', '${preset.protein.toStringAsFixed(0)}g'),
        stat('碳水', '${preset.carbs.toStringAsFixed(0)}g'),
        stat('脂肪', '${preset.fat.toStringAsFixed(0)}g'),
      ],
    );
  }
}

// - device preview操作 - 
class MyScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
      };
}