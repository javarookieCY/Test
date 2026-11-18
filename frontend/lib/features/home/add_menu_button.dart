import 'package:flutter/material.dart';

import '../../utils/constants.dart';
import 'square_icon_button.dart';

class AddMenuButton extends StatelessWidget {
  const AddMenuButton({
    super.key,
    required this.onRecordMeal,
    required this.onRecordExercise,
    required this.onRecordWeight,
  });

  final VoidCallback onRecordMeal;
  final VoidCallback onRecordExercise;
  final VoidCallback onRecordWeight;

  Widget _buildMenuItem(BuildContext sheetContext, IconData icon, String label, VoidCallback action) {
    return ListTile(
      leading: Icon(icon, color: ElementColors.lightUi),
      title: Text(label, style: const TextStyle(color: Colors.white, fontSize: 16)),
      onTap: () {
        Navigator.pop(sheetContext);
        action();
      },
    );
  }

  void _openMenu(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: ElementColors.panelBg,
      builder: (BuildContext sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const SizedBox(height: 8),
              _buildMenuItem(sheetContext, Icons.restaurant, '紀錄餐點', onRecordMeal),
              _buildMenuItem(sheetContext, Icons.directions_run, '記運動', onRecordExercise),
              _buildMenuItem(sheetContext, Icons.monitor_weight_outlined, '記體重', onRecordWeight),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return SquareIconButton(
      icon: Icons.add,
      onPressed: () {
        _openMenu(context);
      },
    );
  }
}
