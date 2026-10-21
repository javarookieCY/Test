import 'package:flutter/material.dart';

// choice類型的answer要畫出一排按鈕，透過按鈕點擊回傳給Survey
class ChoiceAnswer extends StatelessWidget{
  const ChoiceAnswer({
    super.key,
    required this.options,
    required this.selected,
    required this.onSelected,
    required this.horizontal,
  });

  final List<String> options;
  final String? selected;
  // 按鈕觸發
  final ValueChanged<String> onSelected;
  final bool horizontal;

  @override
  Widget build(BuildContext context) {
    final List<ElevatedButton> buttons = [
      for(final String option in options) 
          ElevatedButton(
            onPressed: () => onSelected(option),
            style: ButtonStyle(
              backgroundColor: WidgetStatePropertyAll<Color?>(
                option == selected ? Colors.grey : Colors.white54,
              )
            ), 
            child: Text(
              option,
              style: TextStyle(
                fontSize: 20,
                color: Colors.black,
                fontWeight: FontWeight(900)
              ),
              )
          )
    ];
    return horizontal ?
      Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          for(ElevatedButton button in buttons)
            button
        ],
      ) 
      :
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          for(ElevatedButton button in buttons)
            button
        ],
      );
  }
}