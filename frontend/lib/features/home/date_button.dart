import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../utils/constants.dart';

class DateButton extends StatelessWidget {
  const DateButton({
    super.key,
    required this.selectedDate,
    required this.onDateSelected,
  });

  final DateTime selectedDate;
  final ValueChanged<DateTime> onDateSelected;

  static const List<String> _weekdayNames = <String>['一', '二', '三', '四', '五', '六', '日'];

  Future<void> _openPicker(BuildContext context) async {
    DateTime pickedDate = selectedDate;

    final DateTime? result = await showModalBottomSheet<DateTime>(
      context: context,
      backgroundColor: ElementColors.panelBg,
      builder: (BuildContext sheetContext) {
        return SafeArea(
          child: SizedBox(
            height: 300,
            child: Column(
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      TextButton(
                        onPressed: () {
                          Navigator.pop(sheetContext);
                        },
                        child: const Text(
                          '取消',
                          style: TextStyle(color: ElementColors.lightUi, fontSize: 16),
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.pop(sheetContext, pickedDate);
                        },
                        child: const Text(
                          '確定',
                          style: TextStyle(
                            color: ElementColors.calorieRing,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: CupertinoTheme(
                    data: const CupertinoThemeData(
                      brightness: Brightness.dark,
                      textTheme: CupertinoTextThemeData(
                        dateTimePickerTextStyle: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                      ),
                    ),
                    child: CupertinoDatePicker(
                      mode: CupertinoDatePickerMode.date,
                      dateOrder: DatePickerDateOrder.ymd,
                      initialDateTime: selectedDate,
                      maximumDate: DateTime.now(),
                      onDateTimeChanged: (DateTime value) {
                        pickedDate = value;
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (result != null) {
      onDateSelected(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final int month = selectedDate.month;
    final int day = selectedDate.day;
    final String weekdayName = _weekdayNames[selectedDate.weekday - 1];
    final String text = '$month月$day日 週$weekdayName';

    return GestureDetector(
      onTap: () {
        _openPicker(context);
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(text, style: const TextStyle(color: Colors.grey, fontSize: 14)),
          const SizedBox(width: 2),
          const Icon(Icons.keyboard_arrow_down, color: Colors.grey, size: 18),
        ],
      ),
    );
  }
}
