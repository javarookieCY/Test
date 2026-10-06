import 'package:device_preview/device_preview.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'screens/root_shell.dart';
import 'utils/constants.dart';
import 'utils/scroll_behavior.dart';

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
          brightness: Brightness.dark,
        ),
        // 沒特別指定顏色的文字一律白色（Material 與 Cupertino 元件都是）
        textTheme: Typography.material2021().white.apply(
              bodyColor: Colors.white,
              displayColor: Colors.white,
            ),
        // iOS 風格元件固定用深色模式：預設文字（label 色）就是白色，字型維持系統字型
        cupertinoOverrideTheme: const CupertinoThemeData(brightness: Brightness.dark),
      ),
      home: const RootShell(),
    );
  }
}

