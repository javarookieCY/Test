import 'package:flutter/material.dart';
import 'buttons/to_diet_button.dart';
import 'buttons/to_exercise_button.dart';
import 'buttons/to_stats_button.dart';

class Home extends StatelessWidget{
  const Home({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
      ),

      body: Container(
        color: const Color.fromARGB(255, 46, 46, 46),
        child: Column(
          children: [
            // 不知道放甚麼
            Expanded(
              flex: 2,
              child: Row(
              ),
            ),

            // 胖貓
            Expanded(
              flex: 5,
              child: Container(
                margin: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color.fromARGB(255, 134, 134, 134)
                  )
                ),
                child: Column(  
                  children: [
                    //等級
                    Row( 
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'lv1',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 50,
                            fontWeight: FontWeight(900)
                          ),
                        )
                      ],
                    ),
                    //角色
                    Expanded(
                      child: Container(
                        clipBehavior: Clip.antiAlias,
                        decoration: BoxDecoration(),
                        child: Image.asset('assets/images/home_screen/fatt2.png'),
                      ),
                    ),
                  ],
                ),
              )
            ),

            // "通往其他頁面"按鈕
            Expanded(
              flex: 3,
              child: SafeArea( 
                // SafeArea可以避開手機邊緣上不能放東西的區域(狀態列、電量、瀏海)
                child: 
                  Row(
                    children: [
                      Expanded(
                        child: Exercise()
                      ),
                      Expanded(
                        child: Diet()
                      ),
                      Expanded(
                        child: Stats()
                      ),
                  ],
                )
              ),
            )
          ],
        ),
      ),
    );
  }
}
