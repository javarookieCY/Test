import 'package:flutter/material.dart';
import 'meal_type.dart';
import 'meal_card.dart';

class MealList extends StatelessWidget{
  const MealList({
    super.key,
  });
  

  void _addMeal(MealType meal){

  }
  
  @override
  Widget build(BuildContext context) {
    // 每個餐別(早餐、午餐、晚餐、點心)做一張卡片
    final List<Widget> cards = <Widget>[];
    for (final MealType meal in MealType.values) {
      final Widget card = MealCard(
        meal: meal,
        onAdd: () {
          _addMeal(meal);
        },
      );
      cards.add(card);
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: cards,
    );
  }
}


