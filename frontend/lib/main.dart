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
  void _onFoodAddedToMeal(String mealTitle, String foodName, int calories) async {
    final dateStr = '${_today.year}-${_today.month}-${_today.day}';
    await DBHelper.instance.insertMeal(mealTitle, calories, dateStr);

    setState(() {
      final meal = _mealItems.firstWhere((item) => item.title == mealTitle);
      meal.calories += calories;
      meal.items.add(foodName);

      if (calories <= 0) return;

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

  // 從餐點庫刪除一項食物範本
  Future<void> _deleteFoodFromLibrary(int id) async {
    await DBHelper.instance.deleteFood(id);
    await _loadFoodLibrary();
  }

  // 彈出「新增餐點」表單：輸入名稱、熱量、蛋白質、碳水、脂肪
  void _showAddFoodDialog() {
    final nameController = TextEditingController();
    final caloriesController = TextEditingController();
    final proteinController = TextEditingController();
    final carbsController = TextEditingController();
    final fatController = TextEditingController();

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
              title: const Text('新增餐點到餐點庫'),
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
                            name: name,
                            calories: calories,
                            protein: double.tryParse(proteinController.text.trim()) ?? 0,
                            carbs: double.tryParse(carbsController.text.trim()) ?? 0,
                            fat: double.tryParse(fatController.text.trim()) ?? 0,
                          );

                          final success = await _addFoodToLibrary(food);

                          if (!dialogContext.mounted) return;

                          if (success) {
                            Navigator.pop(dialogContext);
                            // ignore: use_build_context_synchronously
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('已新增「$name」到餐點庫')),
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
        return AlertDialog(
          title: const Text('我的餐點庫'),
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
                        trailing: IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => _deleteFoodFromLibrary(food.id!),
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
              onFoodSelected: (foodName, calories) =>
                  onFoodAdded(meal.title, foodName, calories),
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
  final List<String> items;
  final List<FoodItem> foodLibrary;
  // 選好食物後回傳 (foodName, calories)
  final void Function(String foodName, int calories) onFoodSelected;
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
                  widget.onFoodSelected(name.isEmpty ? '自訂' : name, value);
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
                              widget.onFoodSelected(food.name, food.calories);
                              Navigator.pop(context);
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
                widget.items.join('、'),
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }
}


// - 食物 -
class MealItem {
  MealItem({required this.title, this.calories = 0, List<String>? items})
      : items = items ?? [];
  final String title;
  int calories;
  List<String> items; // 這一餐已經加入的餐點名稱，例如 ['水煮蛋', '地瓜']
}

// 從餐點庫選了某個食物、或手動輸入後，都會呼叫這個 callback
typedef MealFoodAdded = void Function(
  String mealTitle,
  String foodName,
  int calories,
);

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

// - device preview操作 - 
class MyScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
      };
}