import 'package:flutter/material.dart';
import '../../models/food_item.dart';
import '../../models/meal_item.dart';
import '../../utils/constants.dart';

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
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20.0),
                    child: Text(
                      '餐點庫還是空的，先新增幾樣常吃的食物吧！',
                      style: TextStyle(color: Colors.white70),
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
