import 'package:flutter/material.dart';

// 主畫面三大功能按鈕的"外殼+功能"
class HomeButtons extends StatelessWidget{
  const HomeButtons({
    super.key,
    required this.label,
    required this.onTap
  });

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(8),
      
      elevation: 0,
      color: Colors.transparent,

      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: Color.fromARGB(255, 134, 134, 134)
        ),
      ),

      child: InkWell(
        onTap: onTap,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w900
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}