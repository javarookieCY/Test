import 'package:flutter/material.dart';

// ── 新增：引入通知設定跳窗 ──
import 'notification_dialog.dart';
import 'square_icon_button.dart';

// ── 說明：這個元件是首頁右上角的通知圖示按鈕 ──
// 原本功能是「直接發送一則系統通知（震動 + 推播）」
// 現在改為「點擊後開啟通知設定跳窗，讓使用者選擇要開啟哪些通知」
//
// 保留原本的 title / body 參數（讓 home.dart 那邊不用改）
// 但實際上跳窗不需要用到它們，之後真正實作發送功能時再接回來
class NotificationButton extends StatelessWidget {
  const NotificationButton({
    super.key,
    required this.title,
    required this.body,
  });

  final String title;
  final String body;

  // ── 新增：開啟通知設定跳窗的函式 ──
  // 原本的 _send() 是直接發推播，現在換成開 Dialog
  // showDialog() = Flutter 內建的跳窗方法
  // builder: (_) => ... 告訴 Flutter 跳窗裡面要放什麼元件
  void _showNotificationDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => const NotificationDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SquareIconButton(
      icon: Icons.notifications_none,
      // ── 修改：原本呼叫 _send(context)，現在改為開跳窗 ──
      onPressed: () => _showNotificationDialog(context),
    );
  }
}
