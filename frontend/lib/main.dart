import 'package:device_preview/device_preview.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'screens/root_shell.dart';
import 'utils/constants.dart';
import 'utils/scroll_behavior.dart';
import 'screens/start_screen.dart';

void main() {
  runApp(
    DevicePreview(
      enabled: true,
      builder: (context) => const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      locale: DevicePreview.locale(context),
      builder: DevicePreview.appBuilder,
      scrollBehavior: MyScrollBehavior(),
      title: 'Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: ElementColors.accent,
          
        ),
        textTheme: Typography.material2021().white.apply(
              bodyColor: Colors.white,
              displayColor: Colors.white,
            ),
        cupertinoOverrideTheme:
            const CupertinoThemeData(brightness: Brightness.dark),
      ),
      home: const StartScreen(),
    );
  }
}


