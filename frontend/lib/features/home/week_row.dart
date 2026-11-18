/*
import 'package:flutter/material.dart';

import '../../utils/constants.dart';

class WeekRow extends StatelessWidget {
  const WeekRow({
    super.key,
    required this.selectedDate,
    required this.onDateSelected,
  });

  final DateTime selectedDate;
  final ValueChanged<DateTime> onDateSelected;

  static const List<String> _weekdayNames = <String>['一', '二', '三', '四', '五', '六', '日'];

  @override
  Widget build(BuildContext context) {
    final DateTime now = DateTime.now();
    final DateTime today = DateTime(now.year, now.month, now.day);

    final int daysFromMonday = selectedDate.weekday - 1;
    final DateTime monday = DateTime(selectedDate.year, selectedDate.month, selectedDate.day - daysFromMonday);

    final List<Widget> dayWidgets = <Widget>[];
    for (int i = 0; i < 7; i++) {
      final DateTime day = DateTime(monday.year, monday.month, monday.day + i);
      final bool isSelected = day == selectedDate;
      final bool isFuture = day.isAfter(today);

      dayWidgets.add(
        Expanded(
          child: _DayCell(
            weekdayName: _weekdayNames[i],
            month: day.month,
            day: day.day,
            isSelected: isSelected,
            isFuture: isFuture,
            onTap: () {
              onDateSelected(day);
            },
          ),
        ),
      );
    }

    return Row(children: dayWidgets);
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.weekdayName,
    required this.month,
    required this.day,
    required this.isSelected,
    required this.isFuture,
    required this.onTap,
  });

  final String weekdayName;
  final int month;
  final int day;
  final bool isSelected;
  final bool isFuture;
  final VoidCallback onTap;

  static const double _circleSize = 38;

  @override
  Widget build(BuildContext context) {
    Color circleColor = ElementColors.background;
    Color textColor = ElementColors.lightUi;
    if (isSelected) {
      circleColor = ElementColors.calorieRing;
      textColor = Colors.white;
    } else if (isFuture) {
      textColor = Colors.white24;
    }

    VoidCallback? tapHandler;
    if (!isFuture) {
      tapHandler = onTap;
    }

    final String dateText = '$month/$day';

    return GestureDetector(
      onTap: tapHandler,
      child: Column(
        children: <Widget>[
          Text(weekdayName, style: TextStyle(color: textColor, fontSize: 12)),
          const SizedBox(height: 6),
          Container(
            width: _circleSize,
            height: _circleSize,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: circleColor, shape: BoxShape.circle),
            child: Text(
              dateText,
              style: TextStyle(color: textColor, fontSize: 11, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
*/