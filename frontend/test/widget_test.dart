// 原本的 counter 模板測試對這個 App 沒有意義（沒有計數器，且 MyApp 會初始化
// SQLite，widget test 環境沒有 ffi）。改成不碰 DB 的畫面 smoke test。

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/screens/coming_soon_screen.dart';

void main() {
  testWidgets('ComingSoonScreen 顯示 coming soon!', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: ComingSoonScreen()));
    expect(find.text('coming soon!'), findsOneWidget);
  });
}
