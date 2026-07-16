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

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});
  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  String _responseText = 'click';
  bool _isLoading = false;

  // 後端網址
  String get _backendBaseUrl {
    return 'http://localhost:8082';
  }
  
  // GET /api/tasks
  Future<void> fetchData() async {
    setState(() => _isLoading = true);

    try {
      final response = await http.get(
        Uri.parse('$_backendBaseUrl/api/tasks'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _responseText = 'GET 成功\n${data.toString()}';
        });
      } else {
        setState(() {
          _responseText = 'GET 失敗: ${response.statusCode}\n${response.body}';
        });
      }
    } catch (e) {
      setState(() {
        _responseText = 'GET 發生錯誤: $e';
      });
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

      if (response.statusCode == 201) {
        setState(() {
          _responseText = 'POST 成功\n${response.body}';
        });
      } else {
        setState(() {
          _responseText = 'POST 失敗: ${response.statusCode}\n${response.body}';
        });
      }
    } catch (e) {
      setState(() {
        _responseText = 'POST 發生錯誤: $e';
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Text(
                '連線到後端',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                '目前使用: $_backendBaseUrl',
                style: const TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 16),
              if (_isLoading)
                const CircularProgressIndicator()
              else
                const SizedBox(height: 24),
              const SizedBox(height: 16),
              Text(
                _responseText,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // 將方法套用在按鈕上
                  ElevatedButton(
                    onPressed: _isLoading ? null : fetchData,
                    child: const Text('GET /api/tasks'),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton(
                    onPressed: _isLoading ? null : postData,
                    child: const Text('POST /api/tasks'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}