// ============================================================
// 【新檔案】notification_dialog.dart
// 功能：通知設定的跳窗 (Dialog) 元件
// 位置：lib/widgets/home/notification_dialog.dart
// ============================================================

import 'package:flutter/material.dart';
import '../../utils/constants.dart'; // 引入顏色常數（ElementColors）
// （檔案從 lib/widgets/home/ 搬到 lib/features/home/，路徑一樣所以不需調整）

// ── StatefulWidget：因為開關(Switch)的狀態會改變，需要能夠重繪畫面 ──
// 對照 Java Swing：這就像一個有資料的 JDialog，
// 但 Flutter 要用 StatefulWidget 才能讓畫面跟著資料更新。
class NotificationDialog extends StatefulWidget {
  const NotificationDialog({super.key});

  @override
  State<NotificationDialog> createState() => _NotificationDialogState();
}

class _NotificationDialogState extends State<NotificationDialog> {
  // ── 每個通知項目的開關狀態，預設都是關閉(false) ──
  // 對照 Java Swing：就像 JCheckBox 的 isSelected() 狀態
  // Map<String, bool> 是一個「鍵值對」：通知名稱 → 開啟/關閉
  final Map<String, bool> _switches = {
    '運動通知':   false, // 提醒去運動
    '補充水分通知': false, // 提醒喝水
    '飲食紀錄通知': false, // 提醒記錄吃了什麼
    '睡眠提醒':   false, // 提醒準備睡覺
    '每日目標回顧': false, // 每天結束時的目標達成通知
  };

  @override
  Widget build(BuildContext context) {
    // ── AlertDialog：Flutter 內建的跳窗元件 ──
    // 對照 Java Swing：就像 JDialog 或 JOptionPane
    return AlertDialog(
      // 跳窗的背景色，使用專案的 cardBg 顏色
      backgroundColor: ElementColors.panelBg, // 原本是 cardBg，新版 constants.dart 改名為 panelBg

      // ── 跳窗標題區 ──
      title: Row(
        children: [
          // 鈴鐺圖示
          const Icon(
            Icons.notifications_outlined,
            color: Colors.white,
            size: 22,
          ),
          const SizedBox(width: 8), // 圖示和文字之間的間距
          // 標題文字
          const Text(
            '通知設定',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),

      // ── 跳窗內容區 ──
      // SizedBox 限制跳窗內容的最大高度，避免超出螢幕
      content: SizedBox(
        width: double.maxFinite, // 寬度盡量撐滿跳窗
        child: Column(
          mainAxisSize: MainAxisSize.min, // Column 高度只佔需要的空間，不撐滿
          children: [
            // 分隔線
            const Divider(color: Colors.white24, height: 1),
            const SizedBox(height: 8),

            // ── 用 map() 把 _switches 的每個項目都變成一列 UI ──
            // 對照 Java Swing：就像用 for 迴圈把每個 JCheckBox 加進 JPanel
            // .entries 拿到每個 key-value 對，.map() 把它轉成 Widget
            ..._switches.entries.map((entry) {
              return _NotificationRow(
                label: entry.key,   // 通知名稱（如「運動通知」）
                value: entry.value, // 目前的開關狀態（true/false）
                // ── onChanged：當使用者撥動開關時觸發 ──
                // newValue 是開關撥到的新狀態（true=開、false=關）
                onChanged: (newValue) {
                  setState(() {
                    // 把對應通知的狀態更新為新值
                    // 對照 Swing：就像 checkBox.setSelected(newValue)，
                    // 但 Flutter 要包在 setState() 裡才會重繪畫面
                    _switches[entry.key] = newValue;
                  });
                },
              );
            }),
          ],
        ),
      ),

      // ── 跳窗底部的按鈕區 ──
      actions: [
        // 「取消」按鈕：關閉跳窗，不做任何事
        TextButton(
          onPressed: () => Navigator.of(context).pop(), // pop() = 關掉跳窗
          child: const Text(
            '取消',
            style: TextStyle(color: Colors.white54),
          ),
        ),
        // 「確認」按鈕：（目前只是畫面，之後可以在這裡加儲存邏輯）
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(), // 暫時也只是關閉跳窗
          style: ElevatedButton.styleFrom(
            backgroundColor: ElementColors.accent, // 按鈕背景用 accent 灰色
            foregroundColor: Colors.white,          // 文字用白色
          ),
          child: const Text('確認'),
        ),
      ],
    );
  }
}

// ============================================================
// 【私有元件】_NotificationRow
// 功能：單一通知項目的一列（標題 + 開關）
// 為什麼獨立出來：讓上面的 build() 更清楚，不要塞太多重複的程式碼
// ============================================================
class _NotificationRow extends StatelessWidget {
  const _NotificationRow({
    required this.label,     // 通知名稱
    required this.value,     // 開關狀態
    required this.onChanged, // 當開關被撥動時要做什麼
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged; // ValueChanged<bool> = 接受一個 bool 參數的函式型別

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4), // 上下各 4px 間距
      child: Row(
        children: [
          // ── 左邊：通知名稱 ──
          // Expanded 讓文字佔滿剩餘寬度，開關靠右
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
              ),
            ),
          ),

          // ── 右邊：開關（Switch）──
          // 對照 Java Swing：有點像 JToggleButton 或 JCheckBox，
          // 但樣子是滑動開關
          Switch(
            value: value,         // 目前是開(true)還是關(false)
            onChanged: onChanged, // 撥動時呼叫外面傳進來的 onChanged 函式
            activeColor: ElementColors.accent, // 開啟時的顏色
          ),
        ],
      ),
    );
  }
}
