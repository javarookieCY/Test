import 'package:device_preview/device_preview.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'utils/constants.dart';
import 'utils/scroll_behavior.dart';

import 'features/splash/splash_screen.dart';

void main() {
  runApp(
    DevicePreview(
      enabled: true,
      builder: (BuildContext context) {
        return const MyApp();
      },
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
              displayColor: Colors.black,
            ),
        cupertinoOverrideTheme:
            const CupertinoThemeData(brightness: Brightness.dark),
      ),
      // 第一個畫面：封面(1 秒後自己決定要去問卷還是主畫面)
      home: const SplashScreen(),
    );
  }
}


