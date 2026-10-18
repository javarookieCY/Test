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
  // TextAnswer
  final String initialText;

  // answerList有不同種類的回答方式，有choice那就要加options
  // 加static後Survey才能直接透過類別存取answerList
  static const List<AnswerData> answerList = [
    AnswerData(type: AnswerType.choice, options: ['男性', '女性'], horizontal: false),
    AnswerData(type: AnswerType.number, unit: '歲'),
    AnswerData(type: AnswerType.number, unit: '公分'),
    AnswerData(type: AnswerType.number, unit: '公斤'),
    AnswerData(type: AnswerType.choice, options: ['增加肌肉含量', '建立健身基礎', '減掉多餘脂肪'], horizontal: true),
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
          initial: 0, 
          min: data.min, 
          max: data.max, 
          unit: data.unit, 
          onChanged: (v) => onAnswered(v.round().toString())
        );
      case AnswerType.text :
        return TextAnswer(
          initial: data.initialText,
          onChanged: onAnswered,
        );
    }
  }
}

