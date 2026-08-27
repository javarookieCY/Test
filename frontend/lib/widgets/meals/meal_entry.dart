import 'package:flutter/material.dart';
import '../../models/food_item.dart';
import '../../models/meal_item.dart';
import 'meal_card.dart';

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
              onFoodSelected: (foodName, calories, portion) =>
                  onFoodAdded(meal.title, foodName, calories, portion),
            ),
          )
          .toList(),
    );
  }
}
