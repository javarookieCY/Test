import 'package:flutter/material.dart';

import '../../database/database_service.dart';
import '../../shell/shell.dart';
import '../../survey/survey_screen.dart';
import '../../user/user_profile.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() {
    return _SplashScreenState();
  }
}

class _SplashScreenState extends State<SplashScreen> {
  static const Color _blue = Color.fromARGB(255, 0, 124, 226);
  static const Duration _showTime = Duration(seconds: 1);

  @override
  void initState() {
    super.initState();
    _goNext();
  }

  Future<void> _goNext() async {
    await Future<void>.delayed(_showTime);

    final UserProfile? profile = await DatabaseService.instance.getUserProfile();

    if (!mounted) {
      return;
    }

    Widget nextPage;
    if (profile == null) {
      nextPage = const Survey();
    } else {
      nextPage = const Shell();
    }

    Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        pageBuilder: (BuildContext routeContext, Animation<double> animation, Animation<double> secondaryAnimation) {
          return nextPage;
        },
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _blue,
      body: Center(
        child: Container(
          width: 130,
          height: 130,
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.fitness_center,
            size: 50,
            color: _blue,
          ),
        ),
      ),
    );
  }
}
