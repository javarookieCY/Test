import 'package:flutter/material.dart';

import '../../../user/user_profile.dart';

Future<double?> showLogWeightDialog(BuildContext context, UserProfile? profile) async {
  String initialText = '';
  if (profile != null) {
    initialText = profile.weightKg.toStringAsFixed(1);
  }
  final TextEditingController controller = TextEditingController(text: initialText);

  final double? kg = await showDialog<double>(
    context: context,
    builder: (BuildContext dialogContext) {
      String? errorText;

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

  return kg;
}
