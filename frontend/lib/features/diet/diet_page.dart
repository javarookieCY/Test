import 'package:flutter/material.dart';
import 'package:flutter_application_1/utils/constants.dart';

import '../../db_helper.dart';

import '../../home/food/food_item.dart';
import '../../home/food/meal_item.dart';
import '../../home/food/food_search_screen.dart';

import '../../screens/onboarding_screen.dart';
import '../../user/user_profile.dart';

import 'meal_list.dart';


class DietPage extends StatefulWidget {
  const DietPage({super.key});

  @override
  State<DietPage> createState() => _DietPageState();
}

class _DietPageState extends State<DietPage> {
  late final DateTime _today;
  late final List<DateTime> _weekDates;
  late int _selectedIndex;

  // 使用者自訂的餐點庫，從 SQLite 讀出來存在這裡
  List<FoodItem> _foodLibrary = [];

  // 使用者個人資料；null 代表還沒做過 Onboarding
  UserProfile? _profile;

  final List<MealItem> _mealItems = [
    MealItem(title: '早餐'),
    MealItem(title: '午餐'),
    MealItem(title: '晚餐'),
    MealItem(title: '宵夜'),
    MealItem(title: '其他餐點'),
  ];

  // 從 SQLite 讀出目前的餐點庫，更新畫面
  Future<void> _loadFoodLibrary() async {
    final foods = await DBHelper.instance.getAllFoods();
    setState(() => _foodLibrary = foods);
  }

  // 載入個人資料；沒有的話（首次開 App）擋出 Onboarding 頁強制填寫
  Future<void> _loadProfileThenGate() async {
    final p = await DBHelper.instance.getUserProfile();
    if (!mounted) return;
    if (p != null) {
      setState(() => _profile = p);
      return;
    }
    // 等第一幀畫完再 push，避免 build 期間動 Navigator
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final result = await Navigator.push<UserProfile>(
        context,
        MaterialPageRoute(
          builder: (_) => const OnboardingScreen(),
          fullscreenDialog: true,
        ),
      );
      if (mounted && result != null) setState(() => _profile = result);
    });
  }

  // 重新開 Onboarding（編輯模式），存完更新目標卡片

  
  // 記錄今天的體重；體重會影響目標（BMR/蛋白質），所以存完重新載入 profile
  Future<void> _showLogWeightDialog() async {
    final controller = TextEditingController(
      text: _profile?.weightKg.toStringAsFixed(1) ?? '',
    );
    final kg = await showDialog<double>(
      context: context,
      builder: (dialogContext) {
        String? errorText;
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              title: const Text('記錄體重'),
              content: TextField(
                controller: controller,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: '今天的體重 (kg)',
                  errorText: errorText,
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('取消'),
                ),
                ElevatedButton(
                  onPressed: () {
                    final v = double.tryParse(controller.text.trim());
                    if (v == null || v < 25 || v > 400) {
                      setDialogState(() => errorText = '請輸入 25–400 之間的數字');
                      return;
                    }
                    Navigator.pop(dialogContext, v);
                  },
                  child: const Text('儲存'),
                ),
              ],
            );
          },
        );
      },
    );

    if (kg == null) return;
    final now = DateTime.now();
    final dateStr = '${now.year}-${now.month}-${now.day}';
    await DBHelper.instance.logWeight(dateStr, kg);
    final refreshed = await DBHelper.instance.getUserProfile();
    if (!mounted) return;
    setState(() => _profile = refreshed);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('已記錄體重 $kg kg')),
    );
  }

  // 從 SQLite 讀取指定日期的運動消耗熱量
  Future<void> _loadBurnedForDate(DateTime date) async {
    final dateStr = '${date.year}-${date.month}-${date.day}';
    await DBHelper.instance.getBurnedCaloriesByDate(dateStr);
    if (!mounted) return;
  }

  // 從 SQLite 讀取指定日期的喝水紀錄；當天還沒存過就沿用最近一次的目標
  Future<void> _loadWaterForDate(DateTime date) async {
    final dateStr = '${date.year}-${date.month}-${date.day}';
    await DBHelper.instance.getWaterLog(dateStr);
    if (!mounted) return;
    setState(() {
    });
  }

  // 從 SQLite 讀取指定日期的所有餐點明細
  Future<void> _loadMealsForDate(DateTime date) async {
    final dateStr = '${date.year}-${date.month}-${date.day}';
    final mealFoods = await DBHelper.instance.getMealFoodsByDate(dateStr);
    _loadBurnedForDate(date);

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

  // 打開「手動搜尋」畫面：從 TFDA 食品營養庫即時搜尋，挑一筆加進餐點庫。
  // 數值是每 100 克含量，缺值以 0 帶入。
  void _openFoodSearch() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FoodSearchScreen(
          onPick: (ref) => _addFoodToLibrary(
            FoodItem(
              name: ref.name,
              calories: ref.calories,
              protein: ref.protein ?? 0,
              carbs: ref.carbs ?? 0,
              fat: ref.fat ?? 0,
              fiber: ref.fiber ?? 0,
              sodium: ref.sodium ?? 0,
              description: '每 100 克｜來源：食品營養成分資料庫'
                  '${ref.category == null ? '' : '（${ref.category}）'}',
            ),
          ),
        ),
      ),
    );
  }

  // 彈出「新增/修改餐點」表單：輸入名稱、熱量、蛋白質、碳水、脂肪
  void _showAddFoodDialog({FoodItem? foodToEdit}) {
    final isEdit = foodToEdit != null;
    final nameController = TextEditingController(text: foodToEdit?.name ?? '');
    final caloriesController = TextEditingController(text: foodToEdit?.calories.toString() ?? '');
    final proteinController = TextEditingController(text: isEdit && foodToEdit.protein > 0 ? foodToEdit.protein.toString() : '');
    final carbsController = TextEditingController(text: isEdit && foodToEdit.carbs > 0 ? foodToEdit.carbs.toString() : '');
    final fatController = TextEditingController(text: isEdit && foodToEdit.fat > 0 ? foodToEdit.fat.toString() : '');
    final fiberController = TextEditingController(text: isEdit && foodToEdit.fiber > 0 ? foodToEdit.fiber.toString() : '');
    final sodiumController = TextEditingController(text: isEdit && foodToEdit.sodium > 0 ? foodToEdit.sodium.toString() : '');

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
                    TextField(
                      controller: fiberController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: '膳食纖維 (g)，可留空'),
                    ),
                    TextField(
                      controller: sodiumController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: '鈉 (mg)，可留空'),
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
                            fiber: double.tryParse(fiberController.text.trim()) ?? 0,
                            sodium: double.tryParse(sodiumController.text.trim()) ?? 0,
                            // 修改時保留原本的圖片與說明（例如「每 100 克｜來源…」）
                            imagePath: foodToEdit?.imagePath,
                            description: foodToEdit?.description,
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
          actionsAlignment: MainAxisAlignment.spaceEvenly,
          actions: [
            SizedBox(
              width: double.maxFinite,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('關閉'),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _openFoodSearch();
                    },
                    child: const Text('搜尋'),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _showAddFoodDialog();
                    },
                    child: const Text('新增'),
                  ),
                ],
              ),
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
    _loadMealsForDate(_weekDates[_selectedIndex]); // 載入今天的餐點紀錄（含運動消耗）
    _loadWaterForDate(_weekDates[_selectedIndex]); // 載入今天的喝水紀錄
    _loadProfileThenGate(); // 載入個人資料；沒有就跳 Onboarding
  }





  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(

      ),
      body: Container(
        alignment: Alignment.center,
        color: const Color.fromARGB(255, 46, 46, 46),
        child: Column(
          children: [
            Expanded(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 15.0),
                    child: Wrap(
                      alignment: WrapAlignment.end,
                      spacing: 4,
                      children: [
                        TextButton.icon(
                          onPressed: _showLogWeightDialog,
                          icon: const Icon(Icons.monitor_weight_outlined,
                              color: Colors.white),
                          label: const Text(
                            '記錄體重',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: _openFoodSearch,
                          icon: const Icon(Icons.search, color: Colors.white),
                          label: const Text(
                            '搜尋食品',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
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
                  Expanded(child: MealList()),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
