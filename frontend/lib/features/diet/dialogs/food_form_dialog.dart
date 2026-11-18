import 'package:flutter/material.dart';

import '../../../database/database_service.dart';
import '../food/food_item.dart';

double _parseOrZero(String text) {
  final double? value = double.tryParse(text.trim());
  if (value == null) {
    return 0;
  }
  return value;
}

Future<bool> _saveFood(FoodItem food, bool isEdit) async {
  try {
    if (isEdit) {
      await DatabaseService.instance.updateFood(food);
    } else {
      await DatabaseService.instance.insertFood(food);
    }
    return true;
  } catch (e) {
    debugPrint('儲存餐點失敗: $e');
    return false;
  }
}

void showFoodFormDialog(BuildContext context, FoodItem? foodToEdit) {
  final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);

  bool isEdit = false;

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
      String? errorText;
      bool isSaving = false;

      return StatefulBuilder(
        builder: (BuildContext builderContext, StateSetter setDialogState) {
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

          final String? currentError = errorText;
          if (currentError != null) {
            fields.add(const SizedBox(height: 8));
            fields.add(Text(currentError, style: const TextStyle(color: Colors.red)));
          }

          VoidCallback? onCancelPressed;
          if (!isSaving) {
            onCancelPressed = () {
              Navigator.pop(dialogContext);
            };
          }

          VoidCallback? onSavePressed;
          if (!isSaving) {
            onSavePressed = () async {
              final String name = nameController.text.trim();
              final int? calories = int.tryParse(caloriesController.text.trim());

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

              final bool success = await _saveFood(food, isEdit);

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
                messenger.showSnackBar(
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
