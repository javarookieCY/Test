import 'package:flutter/material.dart';

import '../../screens/blank_page.dart';
import 'home_buttons.dart';

class Stats extends StatelessWidget{
  const Stats({super.key});

  @override
  Widget build(BuildContext context) {
   return HomeButtons(
      label: '統計', 
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const BlankPage()),
      ) 
    );
  }
}