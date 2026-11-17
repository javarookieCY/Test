import 'package:flutter/material.dart';

import '../../database/database_service.dart';
import '../../models/food_ref_item.dart';

import 'food/food_item.dart';
import 'food/meal_item.dart';
import 'food/food_search_screen.dart';

import '../../user/user_profile.dart';

import 'meal_list.dart';

class DietPage extends StatefulWidget {
  const DietPage({super.key});

  @override
  State<DietPage> createState() {
    return _DietPageState();
  }
}

class _DietPageState extends State<DietPage> {
  // late：宣告時先不給值，保證在第一次使用前(initState 裡)一定會給
  late final DateTime _today;
  late final List<DateTime> _weekDates; // 這週的週一到週日
  late int _selectedIndex; // 目前看的是這週的第幾天(0 = 週一)

  // 使用者自訂的餐點庫，從 SQLite 讀出來存在這裡
  List<FoodItem> _foodLibrary = <FoodItem>[];

  // 使用者個人資料；null 代表還沒做過 Onboarding
  UserProfile? _profile;

  final List<MealItem> _mealItems = <MealItem>[
    MealItem(title: '早餐'),
    MealItem(title: '午餐'),
    MealItem(title: '晚餐'),
    MealItem(title: '宵夜'),
    MealItem(title: '其他餐點'),
  ];

  // ---------- 小工具 ----------

  /// 日期 → 資料庫用的字串，例如 2026-11-17(不補零)
  String _dateKey(DateTime date) {
    final String year = date.year.toString();
    final String month = date.month.toString();
    final String day = date.day.toString();
    return '$year-$month-$day';
  }

  /// 文字 → 小數；不是數字(或留空)就當 0
  double _parseOrZero(String text) {
    final double? value = double.tryParse(text.trim());
    if (value == null) {
      return 0;
    }
    return value;
  }

  /// 可能是 null 的數字；null 就當 0
  double _valueOrZero(double? value) {
    if (value == null) {
      return 0;
    }
    return value;
  }

  // ---------- 讀資料 ----------

  /// 從 SQLite 讀出目前的餐點庫，更新畫面
  Future<void> _loadFoodLibrary() async {
    final List<FoodItem> foods = await DatabaseService.instance.getAllFoods();
    if (!mounted) {
      return;
    }
    setState(() {
      _foodLibrary = foods;
    });
  }

  /// 載入個人資料(記錄體重時要用)。
  /// 第一次開 App 的個人資料由問卷(Survey)負責填，這裡不再跳出 Onboarding。
  Future<void> _loadProfile() async {
    final UserProfile? profile = await DatabaseService.instance.getUserProfile();
    if (!mounted) {
      return;
    }
    setState(() {
      _profile = profile;
    });
  }

  /// 從 SQLite 讀取指定日期的運動消耗熱量
  /// (注意：目前讀完沒有存起來用，是從舊首頁留下來的)
  Future<void> _loadBurnedForDate(DateTime date) async {
    final String dateKey = _dateKey(date);
    await DatabaseService.instance.getBurnedCaloriesByDate(dateKey);
  }

  /// 從 SQLite 讀取指定日期的所有餐點明細，依餐別放進 _mealItems
  Future<void> _loadMealsForDate(DateTime date) async {
    final String dateKey = _dateKey(date);
    final List<Map<String, dynamic>> mealFoods =
        await DatabaseService.instance.getMealFoodsByDate(dateKey);
    _loadBurnedForDate(date);

    if (!mounted) {
      return;
    }

    setState(() {
      // 先清空每一餐
      for (final MealItem meal in _mealItems) {
        meal.calories = 0;
        meal.items.clear();
      }

      // 每一筆紀錄放進對應的那一餐
      for (final Map<String, dynamic> row in mealFoods) {
        final String mealTitle = row['meal_title'] as String;
        final String foodName = row['food_name'] as String;
        final int calories = row['calories'] as int;
        final num portionNumber = row['portion'] as num;
        final double portion = portionNumber.toDouble();

        // 找這筆紀錄屬於哪一餐；找不到是 -1
        int mealIndex = -1;
        for (int i = 0; i < _mealItems.length; i++) {
          if (_mealItems[i].title == mealTitle) {
            mealIndex = i;
            break;
          }
        }

        if (mealIndex != -1) {
          final MealFoodRecord record = MealFoodRecord(
            name: foodName,
            calories: calories,
            portion: portion,
          );
          _mealItems[mealIndex].items.add(record);
          _mealItems[mealIndex].calories += calories;
        }
      }
    });
  }

  // ---------- 餐點庫的新增、修改、刪除 ----------

  /// 新增一種食物到餐點庫：寫入 SQLite，再重新整理列表
  /// 回傳 true 代表存成功，false 代表存失敗（讓呼叫端知道要不要關對話框）
  Future<bool> _addFoodToLibrary(FoodItem food) async {
    try {
      await DatabaseService.instance.insertFood(food);
      await _loadFoodLibrary();
      return true;
    } catch (e) {
      debugPrint('新增餐點失敗: $e'); // 印在 debug console，方便你自己抓錯
      return false;
    }
  }

  /// 修改餐點庫裡的一種食物
  Future<bool> _updateFoodInLibrary(FoodItem food) async {
    try {
      await DatabaseService.instance.updateFood(food);
      await _loadFoodLibrary();
      return true;
    } catch (e) {
      debugPrint('修改餐點失敗: $e');
      return false;
    }
  }

  /// 從餐點庫刪除一項食物範本
  Future<void> _deleteFoodFromLibrary(int id) async {
    await DatabaseService.instance.deleteFood(id);
    await _loadFoodLibrary();
  }

  // ---------- 記錄體重 ----------

  /// 記錄今天的體重；體重會影響目標（BMR/蛋白質），所以存完重新載入 profile
  Future<void> _showLogWeightDialog() async {
    // 輸入框預設填目前的體重(取到小數點後 1 位)；沒有個人資料就空白
    String initialText = '';
    final UserProfile? currentProfile = _profile;
    if (currentProfile != null) {
      initialText = currentProfile.weightKg.toStringAsFixed(1);
    }
    final TextEditingController controller = TextEditingController(text: initialText);

    // 對話框按「儲存」會回傳輸入的體重；按「取消」或點外面關掉會回傳 null
    final double? kg = await showDialog<double>(
      context: context,
      builder: (BuildContext dialogContext) {
        String? errorText;

        // StatefulBuilder：讓對話框自己可以 setState(顯示錯誤訊息)
        return StatefulBuilder(
          builder: (BuildContext builderContext, StateSetter setDialogState) {
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
              actions: <Widget>[
                TextButton(
                  onPressed: () {
                    Navigator.pop(dialogContext);
                  },
                  child: const Text('取消'),
                ),
                ElevatedButton(
                  onPressed: () {
                    final double? value = double.tryParse(controller.text.trim());
                    if (value == null || value < 25 || value > 400) {
                      setDialogState(() {
                        errorText = '請輸入 25–400 之間的數字';
                      });
                      return;
                    }
                    Navigator.pop(dialogContext, value);
                  },
                  child: const Text('儲存'),
                ),
              ],
            );
          },
        );
      },
    );

    if (kg == null) {
      return;
    }

    final String today = _dateKey(DateTime.now());
    await DatabaseService.instance.logWeight(today, kg);
    final UserProfile? refreshed = await DatabaseService.instance.getUserProfile();

    if (!mounted) {
      return;
    }
    setState(() {
      _profile = refreshed;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('已記錄體重 $kg kg')),
    );
  }

  // ---------- 搜尋食品 ----------

  /// 打開「手動搜尋」畫面：從 TFDA 食品營養庫即時搜尋，挑一筆加進餐點庫。
  /// 數值是每 100 克含量，缺值以 0 帶入。
  void _openFoodSearch() {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (BuildContext routeContext) {
          return FoodSearchScreen(
            onPick: (FoodRefItem ref) {
              // 說明文字：有分類就在後面加上「（分類）」
              String description = '每 100 克｜來源：食品營養成分資料庫';
              final String? category = ref.category;
              if (category != null) {
                description = '$description（$category）';
              }

              final FoodItem food = FoodItem(
                name: ref.name,
                calories: ref.calories,
                protein: _valueOrZero(ref.protein),
                carbs: _valueOrZero(ref.carbs),
                fat: _valueOrZero(ref.fat),
                fiber: _valueOrZero(ref.fiber),
                sodium: _valueOrZero(ref.sodium),
                description: description,
              );
              return _addFoodToLibrary(food);
            },
          );
        },
      ),
    );
  }

  // ---------- 新增 / 修改餐點的表單 ----------

  /// 彈出「新增/修改餐點」表單：輸入名稱、熱量、蛋白質、碳水、脂肪、纖維、鈉。
  /// foodToEdit 有傳就是修改模式，沒傳(null)就是新增模式。
  void _showAddFoodDialog({FoodItem? foodToEdit}) {
    bool isEdit = false;

    // 修改模式：輸入框預設填原本的值(營養素是 0 的留空)
    String nameText = '';
    String caloriesText = '';
    String proteinText = '';
    String carbsText = '';
    String fatText = '';
    String fiberText = '';
    String sodiumText = '';
    if (foodToEdit != null) {
      isEdit = true;
      nameText = foodToEdit.name;
      caloriesText = foodToEdit.calories.toString();
      if (foodToEdit.protein > 0) {
        proteinText = foodToEdit.protein.toString();
      }
      if (foodToEdit.carbs > 0) {
        carbsText = foodToEdit.carbs.toString();
      }
      if (foodToEdit.fat > 0) {
        fatText = foodToEdit.fat.toString();
      }
      if (foodToEdit.fiber > 0) {
        fiberText = foodToEdit.fiber.toString();
      }
      if (foodToEdit.sodium > 0) {
        sodiumText = foodToEdit.sodium.toString();
      }
    }

    final TextEditingController nameController = TextEditingController(text: nameText);
    final TextEditingController caloriesController = TextEditingController(text: caloriesText);
    final TextEditingController proteinController = TextEditingController(text: proteinText);
    final TextEditingController carbsController = TextEditingController(text: carbsText);
    final TextEditingController fatController = TextEditingController(text: fatText);
    final TextEditingController fiberController = TextEditingController(text: fiberText);
    final TextEditingController sodiumController = TextEditingController(text: sodiumText);

    String dialogTitle;
    if (isEdit) {
      dialogTitle = '修改餐點';
    } else {
      dialogTitle = '新增餐點';
    }

    showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        // 用 StatefulBuilder 讓對話框內部能自己 setState 顯示錯誤訊息，
        // 不用把整個 _DietPageState 都 rebuild
        String? errorText;
        bool isSaving = false;

        return StatefulBuilder(
          builder: (BuildContext builderContext, StateSetter setDialogState) {
            // ----- 表單欄位 -----
            final List<Widget> fields = <Widget>[
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
            ];

            // 有錯誤訊息才在最下面顯示紅字
            final String? currentError = errorText;
            if (currentError != null) {
              fields.add(const SizedBox(height: 8));
              fields.add(Text(currentError, style: const TextStyle(color: Colors.red)));
            }

            // ----- 「取消」按鈕：儲存中不能按(onPressed 是 null 時按鈕會變灰) -----
            VoidCallback? onCancelPressed;
            if (!isSaving) {
              onCancelPressed = () {
                Navigator.pop(dialogContext);
              };
            }

            // ----- 「儲存」按鈕：儲存中不能按 -----
            VoidCallback? onSavePressed;
            if (!isSaving) {
              onSavePressed = () async {
                final String name = nameController.text.trim();
                final int? calories = int.tryParse(caloriesController.text.trim());

                // 驗證失敗：直接把原因顯示在對話框裡，不要默默 return
                if (name.isEmpty) {
                  setDialogState(() {
                    errorText = '請輸入名稱';
                  });
                  return;
                }
                if (calories == null) {
                  setDialogState(() {
                    errorText = '熱量請輸入數字';
                  });
                  return;
                }

                setDialogState(() {
                  errorText = null;
                  isSaving = true;
                });

                // 修改時保留原本的 id、圖片與說明（例如「每 100 克｜來源…」）
                int? id;
                String? imagePath;
                String? description;
                if (foodToEdit != null) {
                  id = foodToEdit.id;
                  imagePath = foodToEdit.imagePath;
                  description = foodToEdit.description;
                }

                final FoodItem food = FoodItem(
                  id: id,
                  name: name,
                  calories: calories,
                  protein: _parseOrZero(proteinController.text),
                  carbs: _parseOrZero(carbsController.text),
                  fat: _parseOrZero(fatController.text),
                  fiber: _parseOrZero(fiberController.text),
                  sodium: _parseOrZero(sodiumController.text),
                  imagePath: imagePath,
                  description: description,
                );

                bool success;
                if (isEdit) {
                  success = await _updateFoodInLibrary(food);
                } else {
                  success = await _addFoodToLibrary(food);
                }

                // 存檔期間對話框可能已經被關掉
                if (!dialogContext.mounted) {
                  return;
                }

                if (success) {
                  Navigator.pop(dialogContext);

                  String message;
                  if (isEdit) {
                    message = '已修改「$name」';
                  } else {
                    message = '已新增「$name」';
                  }
                  // ignore: use_build_context_synchronously
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(message)),
                  );
                } else {
                  setDialogState(() {
                    isSaving = false;
                    errorText = '儲存失敗，請稍後再試';
                  });
                }
              };
            }

            // 「儲存」按鈕上的字：儲存中顯示轉圈圈
            Widget saveButtonChild;
            if (isSaving) {
              saveButtonChild = const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              );
            } else {
              saveButtonChild = const Text('儲存');
            }

            return AlertDialog(
              title: Text(dialogTitle),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: fields,
                ),
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: onCancelPressed,
                  child: const Text('取消'),
                ),
                ElevatedButton(
                  onPressed: onSavePressed,
                  child: saveButtonChild,
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ---------- 管理餐點庫 ----------

  /// 彈出「管理餐點庫」列表：可以看目前有哪些餐點、修改、刪除、或新增
  void _showManageFoodLibraryDialog() {
    showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (BuildContext builderContext, StateSetter setDialogState) {
            // 餐點庫是空的：顯示提示文字；有東西：列出來
            Widget libraryContent;
            if (_foodLibrary.isEmpty) {
              libraryContent = const Text('目前還沒有任何餐點，點下方「新增」開始建立吧！');
            } else {
              libraryContent = ListView.builder(
                shrinkWrap: true,
                itemCount: _foodLibrary.length,
                itemBuilder: (BuildContext itemContext, int index) {
                  final FoodItem food = _foodLibrary[index];
                  final int calories = food.calories;

                  return ListTile(
                    title: Text(food.name),
                    subtitle: Text('$calories kcal'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        IconButton(
                          icon: const Icon(Icons.edit, color: Colors.blue),
                          onPressed: () {
                            Navigator.pop(dialogContext);
                            _showAddFoodDialog(foodToEdit: food);
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () async {
                            final int? id = food.id;
                            if (id != null) {
                              await _deleteFoodFromLibrary(id);
                            }
                            setDialogState(() {}); // 刪完重畫對話框的列表
                          },
                        ),
                      ],
                    ),
                  );
                },
              );
            }

            return AlertDialog(
              title: const Text('我的餐點'),
              content: SizedBox(
                width: double.maxFinite,
                child: libraryContent,
              ),
              actionsAlignment: MainAxisAlignment.spaceEvenly,
              actions: <Widget>[
                SizedBox(
                  width: double.maxFinite,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: <Widget>[
                      TextButton(
                        onPressed: () {
                          Navigator.pop(dialogContext);
                        },
                        child: const Text('關閉'),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.pop(dialogContext);
                          _openFoodSearch();
                        },
                        child: const Text('搜尋'),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.pop(dialogContext);
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

  // ---------- 生命週期與畫面 ----------

  @override
  void initState() {
    super.initState();

    final DateTime now = DateTime.now();
    _today = DateTime(now.year, now.month, now.day);

    // 這週的週一：今天往前推 (星期幾 - 1) 天；weekday 1 = 週一 … 7 = 週日
    final DateTime monday = _today.subtract(Duration(days: _today.weekday - 1));
    final List<DateTime> weekDates = <DateTime>[];
    for (int i = 0; i < 7; i++) {
      weekDates.add(monday.add(Duration(days: i)));
    }
    _weekDates = weekDates;
    _selectedIndex = _today.weekday - 1;

    _loadFoodLibrary(); // App 一開啟就先把餐點庫讀出來
    _loadMealsForDate(_weekDates[_selectedIndex]); // 載入今天的餐點紀錄
    _loadProfile(); // 載入個人資料
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: Container(
        alignment: Alignment.center,
        color: const Color.fromARGB(255, 46, 46, 46),
        child: Column(
          children: <Widget>[
            Expanded(
              child: Column(
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 15.0),
                    child: Wrap(
                      alignment: WrapAlignment.end,
                      spacing: 4,
                      children: <Widget>[
                        TextButton.icon(
                          onPressed: () {
                            _showLogWeightDialog();
                          },
                          icon: const Icon(Icons.monitor_weight_outlined, color: Colors.white),
                          label: const Text(
                            '記錄體重',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () {
                            _openFoodSearch();
                          },
                          icon: const Icon(Icons.search, color: Colors.white),
                          label: const Text(
                            '搜尋食品',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () {
                            _showManageFoodLibraryDialog();
                          },
                          icon: const Icon(Icons.list_alt, color: Colors.white),
                          label: const Text(
                            '管理餐點庫',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Expanded(child: MealList()),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
