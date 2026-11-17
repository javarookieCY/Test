import 'package:flutter/material.dart';
import '../../utils/constants.dart';
// ── 新增：引入剛建立的通知跳窗元件 ──
import 'notification_dialog.dart';

// - 頁首 -
class HomeHeader extends StatelessWidget {
  const HomeHeader({super.key, required this.dateLabel});
  final String dateLabel;

  // ── 新增：開啟通知跳窗的函式 ──
  // BuildContext context：Flutter 用來知道「現在在畫面的哪個位置」，
  // 才能在正確的地方顯示跳窗。
  // 對照 Java Swing：就像 JDialog 需要知道 parent frame 才能彈出。
  void _showNotificationDialog(BuildContext context) {
    showDialog(
      context: context, // 告訴 Flutter 在哪個畫面上顯示跳窗
      builder: (_) => const NotificationDialog(), // 建立跳窗內容
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 47.0, width: double.infinity),
        Row(
          children: [
            const SizedBox(width: 15.0),
            ElevatedButton(
              // ── 修改：原本是空的 () {}，現在改為呼叫 _showNotificationDialog ──
              // onPressed 接受一個「函式」：按下去就執行那個函式
              // 這裡用 () => ... 是「箭頭函式」，等於寫 () { _showNotificationDialog(context); }
              onPressed: () => _showNotificationDialog(context),
              child: const Icon(Icons.notification_add),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.all(15.0),
          child: Row(
            children: [Text(dateLabel, style: kTitleText)],
          ),
        ),
      ],
    );
  }
}
