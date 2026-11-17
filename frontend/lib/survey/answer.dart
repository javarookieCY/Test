import 'package:flutter/material.dart';
import 'choice_answer.dart';
import 'number_answer.dart';
import 'text_answer.dart';

// 回答方式
enum AnswerType {
  choice,
  number,
  text
}

// 回答本身
class AnswerData {
  const AnswerData({
    required this.type,
    this.options = const [],
    this.horizontal = true,
    this.min = 0,
    this.max = 200,
    this.unit = '',
    this.initial = 0,
    this.initialText = '',
  });

  final AnswerType type; 
  // ChoiceAnswer
  final List<String> options; 
  final bool horizontal;
  // NumberAnswer
  final int min;
  final int max;
  final String unit;
  final int initial;
  // TextAnswer
  final String initialText;

  // answerList有不同種類的回答方式，有choice那就要加options
  // 加static後Survey才能直接透過類別存取answerList
  // 順序要和 question.dart 的 questions、survey_profile.dart 的 SurveyIndex 一致
  // choice 的選項順序也有意義：survey_profile.dart 用「第幾個選項」換算成性別、作息、目標、器材
  // number 的 max 不會出現在滾輪上(滾輪顯示 min 到 max - 1)
  static const List<AnswerData> answerList = <AnswerData>[
    // 0 性別
    AnswerData(type: AnswerType.choice, options: <String>['男性', '女性'], horizontal: false),
    // 1 年齡：10–99 歲
    AnswerData(type: AnswerType.number, unit: '歲', initial: 20, min: 10, max: 100),
    // 2 身高：100–229 公分
    AnswerData(type: AnswerType.number, unit: '公分', initial: 170, min: 100, max: 230),
    // 3 體重：25–199 公斤
    AnswerData(type: AnswerType.number, unit: '公斤', initial: 60, min: 25, max: 200),
    // 4 作息(活動量)：日常生活與工作，不含刻意運動
    AnswerData(
      type: AnswerType.choice,
      options: <String>[
        '久坐・多數時間坐著',
        '輕度・常走動或通勤',
        '中度・站著或走動為主',
        '高度・體力勞動',
        '非常高・重度勞動',
      ],
      horizontal: true,
    ),
    // 5 目標
    AnswerData(type: AnswerType.choice, options: <String>['增加肌肉含量', '建立健身基礎', '減掉多餘脂肪'], horizontal: true),
    // 6 每週運動幾天：1–6 天(至少留一天休息)
    AnswerData(type: AnswerType.number, unit: '天', initial: 3, min: 1, max: 7),
    // 7 器材
    AnswerData(
      type: AnswerType.choice,
      options: <String>['只有徒手', '有啞鈴', '健身房(全部器材)'],
      horizontal: true,
    ),
    // 8 名字
    AnswerData(type: AnswerType.text, initialText: ''),
  ];
}

// 回答的呈現方式
class AnswerText extends StatelessWidget {
  const AnswerText({
    super.key,
    required this.data,
    required this.selected,
    required this.onAnswered,
  });

  
  final AnswerData data;
  final String? selected; // 2種: 選項被選中/還沒被選中(null)
  final ValueChanged<String> onAnswered; // 選中這個選項時，這個選項要做甚麼事
  
  @override
  Widget build(BuildContext context) {
    switch(data.type) {
      case AnswerType.choice :
        return ChoiceAnswer(
          options: data.options, 
          selected: selected, 
          onSelected: onAnswered,
          horizontal: data.horizontal,
        );
      case AnswerType.number :
        return NumberAnswer(
          initial: data.initial, 
          min: data.min, 
          max: data.max, 
          unit: data.unit, 
          onChanged: (int value) {
            onAnswered(value.toString()); // 數字轉成文字，和其他題目一樣存成 String
          }
        );
      case AnswerType.text :
        return TextAnswer(
          initial: data.initialText,
          onChanged: onAnswered,
        );
    }
  }
}

