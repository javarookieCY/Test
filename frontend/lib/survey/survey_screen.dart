import 'package:flutter/material.dart';
import 'package:flutter_application_1/database/database_service.dart';
import 'package:flutter_application_1/models/exercise_task.dart';
import 'package:flutter_application_1/shell/shell.dart';
import 'package:flutter_application_1/user/user_profile.dart';
import 'package:flutter_application_1/utils/workout_planner.dart';
import 'question.dart';
import 'answer.dart';
import 'survey_profile.dart';


class Survey extends StatefulWidget {
  const Survey({super.key});

  @override
  State<Survey> createState() {
    return _SurveyState();
  }
}

class _SurveyState extends State<Survey> {
  int _current = 0;

  // 最後一題按下去後，存檔期間設成 true：按鈕變灰，避免連按存兩次
  bool _saving = false;

  // selected：每一題的答案，還沒回答是 null
  final List<String?> _answers = List<String?>.filled(QuestionData.questions.length, null);

  bool get _isLastQuestion {
    return _current == QuestionData.questions.length - 1;
  }

  void _nextQustion() {
    if (_isLastQuestion) {
      _finish();
      return;
    }
    setState(() {
      _current++;
    });
  }

  void _backToLastQuestion() {
    if (_current > 0) {
      setState(() {
        _current--;
      });
    }
  }

  // onChanged
  void onAnswered(String value) {
    setState(() {
      _answers[_current] = value;
    });
  }

  /// 全部答完：存個人資料 → 排本週運動計畫 → 進主畫面
  Future<void> _finish() async {
    setState(() {
      _saving = true;
    });

    try {
      // 1. 答案 → 個人資料，存進資料庫(熱量、蛋白質目標都從這裡算)
      final UserProfile profile = profileFromAnswers(_answers);
      await DatabaseService.instance.saveUserProfile(profile);

      // 2. 依個人資料排出本週運動計畫，寫進訓練清單
      final WeeklyPlan plan = weeklyPlanFromProfile(profile);
      final Map<String, List<ExerciseTask>> tasksByDate = planToTasks(plan, DateTime.now());
      await DatabaseService.instance.applyWeeklyPlan(tasksByDate);
    } catch (e) {
      debugPrint('問卷存檔失敗: $e');
      if (!mounted) {
        return;
      }
      setState(() {
        _saving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('儲存失敗，請稍後再試')),
      );
      return;
    }

    if (!mounted) {
      return;
    }

    // 3. 進主畫面，並清掉前面所有頁面(按返回鍵不會回到問卷)
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(
        builder: (BuildContext routeContext) {
          return const Shell();
        },
      ),
      (Route<dynamic> route) {
        return false; // false = 前面的頁面全部移除
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // 「繼續」按鈕：這題還沒回答、或正在存檔時不能按(onPressed 是 null 時按鈕變灰)
    VoidCallback? onContinuePressed;
    if (_answers[_current] != null && !_saving) {
      onContinuePressed = () {
        _nextQustion();
      };
    }

    // 最後一題的按鈕字改成「完成」
    String continueText;
    if (_isLastQuestion) {
      continueText = '完成';
    } else {
      continueText = '繼續';
    }

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsetsGeometry.fromLTRB(15, 0, 0, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: <Widget>[
                  Visibility(
                    visible: _current > 0,
                    maintainAnimation: true,
                    maintainSize: true,
                    maintainState: true,
                    child: IconButton(
                      onPressed: () {
                        _backToLastQuestion();
                      },
                      icon: const Icon(Icons.arrow_back_ios_new),
                    ),
                  )
                ],
              ),
            ),
            const SizedBox(
              height: 50,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(25, 0, 0, 0),
              child: Row(
                children: <Widget>[
                  QuestionText(text: QuestionData.questions[_current])
                ],
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: <Widget>[
                Container(
                  height: 180,
                  width: 180,
                  clipBehavior: Clip.antiAlias,
                  decoration: const BoxDecoration(),
                  child: const Image(
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
                children: <Widget>[
                  Expanded(
                    flex: 8,
                    child: AnswerText(
                      key: ValueKey<int>(_current),
                      data: AnswerData.answerList[_current],
                      selected: _answers[_current],
                      onAnswered: (String value) {
                        onAnswered(value);
                      },
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        ElevatedButton(
                          onPressed: onContinuePressed,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.black,
                            foregroundColor: Colors.white,
                          ),
                          child: Text(
                            continueText,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight(400),
                            ),
                          ),
                        )
                      ],
                    ),
                  )
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}
