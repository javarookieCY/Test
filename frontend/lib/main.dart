import 'dart:convert';

import 'package:device_preview/device_preview.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(
    DevicePreview(
      enabled: true,
      builder: (context) => const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      locale: DevicePreview.locale(context),
      builder: DevicePreview.appBuilder,
      title: 'Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const MyHomePage(title: 'Demo'),
    );
  }
}

// - 常數 -
class ElementColors {
  static const background = Color.fromARGB(255, 30, 30, 32);
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

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});
  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  String _responseText = 'click';
  bool _isLoading = false;

  static const _backendBaseUrl = 'http://localhost:8080';

  // GET /api/tasks
  Future<void> fetchData() async {
    setState(() => _isLoading = true);
    try {
      final response = await http.get(Uri.parse('$_backendBaseUrl/api/tasks'));
      setState(() {
        _responseText = response.statusCode == 200
            ? 'GET 成功\n${jsonDecode(response.body)}'
            : 'GET 失敗: ${response.statusCode}\n${response.body}';
      });
    } catch (e) {
      setState(() => _responseText = 'GET 發生錯誤: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // POST /api/tasks
  Future<void> postData() async {
    setState(() => _isLoading = true);
    try {
      final response = await http.post(
        Uri.parse('$_backendBaseUrl/api/tasks'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'title': 'hello from flutter',
          'description': 'created by Flutter app',
          'completed': false,
        }),
      );
      setState(() {
        _responseText = response.statusCode == 201
            ? 'POST 成功\n${response.body}'
            : 'POST 失敗: ${response.statusCode}\n${response.body}';
      });
    } catch (e) {
      setState(() => _responseText = 'POST 發生錯誤: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        alignment: Alignment.center,
        color: ElementColors.background,
        child: Column(
          children: [
            const _HomeHeader(),

            Expanded(
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Column(
                      children: [
                        const _WeekRow(),
                        const SizedBox(height: 15.0),
                        const _StreakInfoRow(),
                        const SizedBox(height: 15.0),
                        const FoodStreakSection(),
                        const _CaloriesFetch(),
                        const _Decoy(),
                        
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// - 頁首 -
class _HomeHeader extends StatelessWidget {
  const _HomeHeader();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 47.0, width: double.infinity),
        Row(
          children: [
            const SizedBox(width: 15.0),
            ElevatedButton(
              onPressed: () {},
              child: const Icon(Icons.notification_add),
            ),
          ],
        ),
        const Padding(
          padding: EdgeInsets.all(15.0),
          child: Row(
            children: [Text('今天', style: kTitleText)],
          ),
        ),
      ],
    );
  }
}

// - 一週 -
class _WeekRow extends StatelessWidget {
  const _WeekRow();

  static const _days = ['一', '二', '三', '四', '五', '六', '日'];

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: List.generate(_days.length, (index) {
        return Column(
          children: [
            Container(
              height: 30,
              width: 30,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: ElementColors.dayBorder),
                color: ElementColors.dayBg,
              ),
            ),
            const SizedBox(height: 4),
            Text(_days[index], style: const TextStyle(color: Colors.grey)),
          ],
        );
      }),
    );
  }
}

// - 連續紀錄 -
class _StreakInfoRow extends StatelessWidget {
  const _StreakInfoRow();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        SizedBox(width: 15.0),
        Text('0', style: kGreyBoldText),
        SizedBox(width: 2.0),
        Icon(Icons.done, color: Colors.grey),
        SizedBox(width: 15.0),
        Text('記錄食物來開始連續紀錄', style: kGreyBoldText),
      ],
    );
  }
}

// - 飲食計畫 -
class FoodStreakSection extends StatefulWidget {
  const FoodStreakSection({super.key});

  @override
  State<FoodStreakSection> createState() => _FoodStreakSectionState();
}

class _FoodStreakSectionState extends State<FoodStreakSection> {
  bool _isExpanded = false;
  

  @override
  Widget build(BuildContext context) {
    double containerHeight;
    Widget buttonLook;

    if(_isExpanded == true){
      containerHeight = 100.0;
      buttonLook = const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.explore,
              color: Colors.white,
          ),
          SizedBox(width: 6.0,),
          Text('探索計畫',
            style: TextStyle(
              color: Colors.white,
            ),
          ),
        ],
      );
    }
    else{
      containerHeight = 0.0;
      buttonLook = const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.expand_more,
              color: Colors.white,
            ),
          SizedBox(width: 6.0,),
          Text('展開',
            style: TextStyle(
              color: Colors.white,
            ),
          ),
        ]
      );
    }

    return Column(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: containerHeight,
          width: double.infinity,
          margin: const EdgeInsets.symmetric(horizontal: 15.0),
          decoration: BoxDecoration(
            color: ElementColors.dayBg,
            borderRadius: BorderRadius.circular(8.0),
          ),
        ),
        const SizedBox(height: 8.0),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
              ),
              onPressed: () => setState(() => _isExpanded = !_isExpanded),
              child: buttonLook,
            ),
            const SizedBox(width: 15.0),
          ],
        ),
      ],
    );
  }
}

// - 熱量攝取 -
class _CaloriesFetch extends StatelessWidget{
  const _CaloriesFetch();

  @override
  Widget build(BuildContext context){
    return Padding(
      padding: const EdgeInsets.all(15.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _CaloriesRow(label: "剩餘熱量", value: "3200 kcal",),
          const SizedBox(height: 5.0,),
          _CaloriesRow(label: "已攝取熱量", value: "0 kcal",),
        ],
      ),
    );
  }
}
class _CaloriesRow extends StatelessWidget{
  const _CaloriesRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: Colors.white),),
        Text(value, style: TextStyle(color: Colors.white),),
      ],
    );
  } 
}

// - 填充物 -
class _Decoy extends StatelessWidget{
  const _Decoy();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List<Widget>.generate(
        20,
        (index) => Container(
          height: 50.0,
          color: Colors.amberAccent,
        ),
      ),
    );
  }
}