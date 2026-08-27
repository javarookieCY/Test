import 'package:flutter/material.dart';
import '../../utils/constants.dart';

// - 一週 -
class WeekRow extends StatelessWidget {
  const WeekRow({
    super.key,
    required this.today,
    required this.weekDates,
    required this.selectedIndex,
    required this.onSelect,
  });

  final DateTime today;
  final List<DateTime> weekDates;
  final int selectedIndex;
  final ValueChanged<int> onSelect;

  static const _dayLabels = ['一', '二', '三', '四', '五', '六', '日'];

  Color _fillColor({required bool isToday, required bool isSelected, required bool isPast}) {
    if (isSelected && isToday) return Colors.green;
    if (isToday) return Colors.grey.shade300;
    if (isPast) return Colors.grey.shade800;
    return ElementColors.background;
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: List.generate(7, (index) {
        final date = weekDates[index];
        final isToday = date == today;
        final isSelected = index == selectedIndex;
        final isPast = date.isBefore(today);

        return GestureDetector(
          onTap: () => onSelect(index),
          child: Column(
            children: [
              Container(
                height: 30,
                width: 30,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _fillColor(isToday: isToday, isSelected: isSelected, isPast: isPast),
                  border: Border.all(
                    color: isSelected ? Colors.green : const Color.fromARGB(255, 87, 85, 85),
                    width: 2.0,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(_dayLabels[index], style: const TextStyle(color: Colors.grey)),
            ],
          ),
        );
      }),
    );
  }
}
