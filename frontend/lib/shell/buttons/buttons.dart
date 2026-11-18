import 'package:flutter/material.dart';

class Buttons extends StatelessWidget {
  const Buttons({
    super.key,
    required this.icon,
    required this.isActive,
    required this.buttonIndex,
    required this.onButtonTapped,
  });

  final IconData icon; 
  final bool isActive; // 我是不是被選中(由按鈕列算好傳進來)
  final int buttonIndex; // 我是第幾顆(固定不變)
  final ValueChanged<int> onButtonTapped; // 被點時呼叫，並帶上自己的編號

  static const Color selectedColor = Color.fromARGB(255, 0, 124, 226);
  static const Color unselectedColor = Colors.white;

  @override
  Widget build(BuildContext context) {
    // 被選中用藍色，沒被選中用白色
    Color iconColor;
    if (isActive) {
      iconColor = selectedColor;
    } else {
      iconColor = unselectedColor;
    }

    return IconButton(
      onPressed: () {
        onButtonTapped(buttonIndex); // 被點時，把自己的編號回報給父層
      },
      icon: Icon(icon),
      iconSize: 30,
      color: iconColor,
      style: IconButton.styleFrom(
        fixedSize: const Size(50, 50),
        padding: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }
}
