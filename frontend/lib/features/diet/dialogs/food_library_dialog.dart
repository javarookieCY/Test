import 'package:flutter/material.dart';

import '../../../database/database_service.dart';
import '../food/food_item.dart';

class FoodLibraryDialog extends StatefulWidget {
  const FoodLibraryDialog({
    super.key,
    required this.onEdit,
    required this.onSearch,
    required this.onAdd,
  });

  final ValueChanged<FoodItem> onEdit;
  final VoidCallback onSearch;
  final VoidCallback onAdd;

  @override
  State<FoodLibraryDialog> createState() {
    return _FoodLibraryDialogState();
  }
}

class _FoodLibraryDialogState extends State<FoodLibraryDialog> {
  List<FoodItem> _foods = <FoodItem>[];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final List<FoodItem> foods = await DatabaseService.instance.getAllFoods();
    if (!mounted) {
      return;
    }
    setState(() {
      _foods = foods;
      _loading = false;
    });
  }

  Future<void> _delete(int id) async {
    await DatabaseService.instance.deleteFood(id);
    await _load();
  }

  Widget _buildRow(FoodItem food) {
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
              Navigator.pop(context);
              widget.onEdit(food);
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.red),
            onPressed: () {
              final int? id = food.id;
              if (id != null) {
                _delete(id);
              }
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget libraryContent;
    if (_loading) {
      libraryContent = const Center(child: CircularProgressIndicator());
    } else if (_foods.isEmpty) {
      libraryContent = const Text('目前還沒有任何餐點，點下方「新增」開始建立吧！');
    } else {
      libraryContent = ListView.builder(
        shrinkWrap: true,
        itemCount: _foods.length,
        itemBuilder: (BuildContext itemContext, int index) {
          return _buildRow(_foods[index]);
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
                  Navigator.pop(context);
                },
                child: const Text('關閉'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  widget.onSearch();
                },
                child: const Text('搜尋'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  widget.onAdd();
                },
                child: const Text('新增'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
