import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class MyChart extends StatefulWidget {
    const MyChart({super.key});

    @override
    State<MyChart> createState() => _MyChartState();
}

class _MyChartState extends State<MyChart> {
    @override
    Widget build(BuildContext context) {
        return Container(
            color: Colors.red,
            child: Stack(
                children:[
                  LineChart(
                    LineChartData(),
                    duration: Duration(milliseconds: 900),
                    curve:Curves. //媽的黑鬼
                  )
                ]
            )
        );
    }
}