import 'package:flutter/material.dart';

class ElementColors {
  // App 主色調（深色背景）
  static const background = Color(0xFF1B262C);

  // 卡片 / 次表面：比背景亮一階
  static const cardBg = Color(0xFF22333B);

  // 強調色：所有原本的綠色、按鈕、選取狀態都用這個
  static const accent = Color(0xFF3282B8);

  // 未選取狀態用：比 accent 暗一階，但仍看得清文字
  static const accentDim = Color(0xFF1E4E63);

  // 淺色介面色調：高亮文字、小標示、進度等
  static const lightUi = Color(0xFFBBE1FA);

  static const dayBg = Color.fromARGB(100, 116, 116, 116);
  static const dayBorder = Color.fromARGB(255, 179, 179, 179);
}

const kGreyBoldText = TextStyle(color: Colors.grey, fontWeight: FontWeight.bold);
const kTitleText = TextStyle(
  color: Colors.white,
  fontSize: 18.0,
  fontWeight: FontWeight.w600,
  letterSpacing: 2,
);

/// 深色底上的分段按鈕（SegmentedButton）共用樣式：
/// 選取 = accent + 白字；未選取 = accentDim + 淺藍字，避免整顆變黑看不到選項。
ButtonStyle segmentedStyleOnDark() {
  return ButtonStyle(
    backgroundColor: WidgetStateProperty.resolveWith((states) {
      return states.contains(WidgetState.selected)
          ? ElementColors.accent
          : ElementColors.accentDim;
    }),
    foregroundColor: WidgetStateProperty.resolveWith((states) {
      return states.contains(WidgetState.selected)
          ? Colors.white
          : ElementColors.lightUi;
    }),
    side: WidgetStateProperty.all(
      const BorderSide(color: ElementColors.accent, width: 1),
    ),
  );
}
