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
    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        for (final meal in MealType.values)
          MealCard(meal: meal, onAdd: () => _addMeal(meal)),
      ],
    );
  }
}


