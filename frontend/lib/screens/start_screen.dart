import 'package:flutter/material.dart';
import '../survey/survey_screen.dart';

/*
  加了動畫，所以要用StatefulWidget
  State<類別> createState() {return _類別State()}


*/
class StartScreen extends StatefulWidget {
  const StartScreen({super.key});

  @override
  State<StartScreen> createState() => _StartScreenState();
}

class _StartScreenState extends State<StartScreen> {
  bool _shown = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) {
        if(mounted) {
          setState(() {_shown = true;});
        }
      }
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            SizedBox(
              height: 60,
            ),
            Text(
              'Fitness',
              style: TextStyle(
                color: Colors.black,
                fontSize: 50,
                fontWeight: FontWeight(900),
              ),
            ),
            Text(
              '&',
              style: TextStyle(
                color: Colors.black,
                fontSize: 40,
                fontWeight: FontWeight(700),
              ),
            ),
            Text(
              'Healthy',
              style: TextStyle(
                color: Colors.black,
                fontSize: 50,
                fontWeight: FontWeight(900),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(50),
                child: Center(
                  child: AnimatedSlide(
                    offset: _shown ? Offset.zero : const Offset(0, 0.3),
                    duration: const Duration(milliseconds: 900),
                    curve: Curves.easeOutCubic,
                    child: AnimatedOpacity(
                      opacity: _shown ? 1 : 0,
                      duration: const Duration(milliseconds: 900),
                      child: Container(
                        clipBehavior: Clip.antiAlias,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(40),
                        ),
                        child: const Image(
                          image: AssetImage('assets/images/start_screen/workout.jpg'),
                          fit: BoxFit.cover,
                          
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            

            const SizedBox(height: 20),

            TextButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const Survey()),
                );
              },
              
              child: const Text(
                '> start <',
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 40
                ),
              ),
            ),

            const SizedBox(height: 50),
          ],
        ),
      ),
    );
  }
}