import 'package:flutter/material.dart';

// 問題本身
// 順序要和 answer.dart 的 answerList、survey_profile.dart 的 SurveyIndex 一致
class QuestionData {
  static const List<String> questions = <String>[
    '你的性別是?',
    '你的年齡為?',
    '你有多高?',
    '你的體重為?',
    '你平常的作息是?',
    '你的目標是?',
    '每週想運動幾天?',
    '你有哪些器材?',
    '最後，你的大名是?'
  ];
}

// 問題呈現方式
class QuestionText extends StatelessWidget{
  const QuestionText({
    super.key,
    required this.text
  });

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          text,
          style: TextStyle(
            color: Colors.black,
            fontSize: 40,
            fontWeight: FontWeight(600)
          ),
        )
      ],
    );
  }
}