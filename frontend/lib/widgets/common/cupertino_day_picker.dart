import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show SynchronousFuture;
import 'package:flutter/material.dart';

import '../../utils/constants.dart';

/// 從底部滑出的 iOS 日期滾輪，選一天；按取消回傳 null。
/// App 沒有載入 flutter_localizations，滾輪預設會顯示英文月份，
/// 這裡只針對這個滾輪換成「2026年 10月 7日」的中文格式。
Future<DateTime?> showCupertinoDayPicker(
  BuildContext context, {
  required DateTime initial,
  DateTime? minimumDate,
  DateTime? maximumDate,
}) {
  var picked = initial;
  return showCupertinoModalPopup<DateTime>(
    context: context,
    builder: (ctx) => Material(
      color: ElementColors.cardBg,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
      clipBehavior: Clip.antiAlias,
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 300,
          child: Column(
            children: [
              Row(
                children: [
                  CupertinoButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('取消'),
                  ),
                  const Expanded(
                    child: Text('選擇日期',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                  ),
                  CupertinoButton(
                    onPressed: () => Navigator.pop(
                        ctx, DateTime(picked.year, picked.month, picked.day)),
                    child: const Text('完成', style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
              const Divider(height: 1, color: Colors.white12),
              Expanded(
                child: Localizations.override(
                  context: ctx,
                  delegates: const [_ZhDatePickerDelegate()],
                  child: CupertinoDatePicker(
                    mode: CupertinoDatePickerMode.date,
                    initialDateTime: initial,
                    minimumDate: minimumDate,
                    maximumDate: maximumDate,
                    onDateTimeChanged: (d) => picked = d,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _ZhDatePickerLocalizations extends DefaultCupertinoLocalizations {
  const _ZhDatePickerLocalizations();

  @override
  String datePickerYear(int yearIndex) => '$yearIndex年';

  @override
  String datePickerMonth(int monthIndex) => '$monthIndex月';

  @override
  String datePickerStandaloneMonth(int monthIndex) => '$monthIndex月';

  @override
  String datePickerDayOfMonth(int dayIndex, [int? weekDay]) => '$dayIndex日';

  @override
  DatePickerDateOrder get datePickerDateOrder => DatePickerDateOrder.ymd;
}

class _ZhDatePickerDelegate extends LocalizationsDelegate<CupertinoLocalizations> {
  const _ZhDatePickerDelegate();

  @override
  bool isSupported(Locale locale) => true;

  @override
  Future<CupertinoLocalizations> load(Locale locale) =>
      SynchronousFuture(const _ZhDatePickerLocalizations());

  @override
  bool shouldReload(_ZhDatePickerDelegate old) => false;
}
