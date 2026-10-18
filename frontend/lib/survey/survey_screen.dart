import 'package:flutter/material.dart';
import 'question.dart';
import 'answer.dart';
import '../screens/root_shell.dart';

class Survey extends StatefulWidget {
  const Survey({super.key});
  @override
  State<Survey> createState() => _SurveyState();
}
// 狀態放在需要它的最高那一層
class _SurveyState extends State<Survey> {
  // 現在是第幾個問題
  int _current = 0;

  void _nextQustion() {
    if(_current < QuestionData.questions.length - 1) {
      setState(() {
        _current++;
      });
    }
    else {
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const RootShell()));
    }
  }
 
  void _backToLastQuestion() {
    if(_current > 0) {
      setState(() {
        _current--;
      });
    }
  }

  // selected
  final List<String?> _answers = List.filled(QuestionData.questions.length, null);
  // onChanged
  void onAnswered(String value) {
    setState(() {
      _answers[_current] = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsetsGeometry.fromLTRB(15, 0, 0, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  Visibility(
                    visible: _current > 0,
                    maintainAnimation: true,
                    maintainSize: true,
                    maintainState: true,
                    child: IconButton(
                      onPressed: _backToLastQuestion,
                      icon: Icon(Icons.arrow_back_ios_new),
                    ),
                  )
                ],
              ),
            ),
            SizedBox(
              height: 50,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(25, 0, 0, 0),
              child: Row(
                children: [
                  QuestionText(text: QuestionData.questions[_current])
                ],
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Container(
                  height: 180,
                  width: 180,
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(),
                  child: Image(
                    image: AssetImage('assets/images/survey_screen/survey.jpg'),
                    fit: BoxFit.cover,
                  ),
                )
              ],
            ),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    flex: 8,
                    child: AnswerText(
                      key: ValueKey(_current),
                      data: AnswerData.answerList[_current], 
                      selected: _answers[_current], 
                      onAnswered: onAnswered
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        FilledButton(
                          onPressed: _answers[_current] == null ? null : _nextQustion,
                          child: Text(
                            '繼續',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight(400)
                            ),
                          )
                        )
                      ],
                    ),
                  )
                ],
              ),
            )
          ],
        )
      )
    );
  }

}

