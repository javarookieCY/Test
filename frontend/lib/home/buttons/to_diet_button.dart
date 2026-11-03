import 'package:flutter/material.dart';
import 'package:flutter_application_1/features/diet/diet_page.dart';
import 'package:flutter_application_1/home/buttons/home_buttons.dart';

class Diet extends StatelessWidget{
  const Diet({super.key});

  @override
  Widget build(BuildContext context) {
    return HomeButtons(
      label: '飲食', 
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const DietPage()),
      ) 
    );
  }
}