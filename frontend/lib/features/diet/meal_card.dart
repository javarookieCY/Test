import 'package:flutter/material.dart';
import 'meal_type.dart';


class MealCard extends StatelessWidget{
  const MealCard({
    super.key,
    required this.meal,
    required this.onAdd,
  });

  final MealType meal;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 120,
      child: Card(
        margin: EdgeInsets.fromLTRB(8, 4, 8, 4),
        elevation: 0,
        clipBehavior: Clip.antiAlias,
        color: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(
            color: Color.fromARGB(255, 134, 134, 134)
          )
        ),
      
        child: InkWell(
          onTap: onAdd,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.add,
                  size: 36,            
                  color: Colors.grey,
                ),
                const SizedBox(
                  width: 8,
                ),
                Text(
                  meal.label,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}