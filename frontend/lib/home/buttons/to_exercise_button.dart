import 'package:flutter/material.dart';
import '../../screens/blank_page.dart';
import 'home_buttons.dart';

class Exercise extends StatelessWidget{
  const Exercise({super.key});

  @override
  Widget build(BuildContext context) {
   return HomeButtons(
      label: '運動', 
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const BlankPage()),
      ) 
    );
  }
}