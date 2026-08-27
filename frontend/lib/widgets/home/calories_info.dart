import 'package:flutter/material.dart';

// - 熱量攝取 -
class CaloriesFetch extends StatelessWidget {
  const CaloriesFetch({
    super.key,
    required this.remaining,
    required this.consumed,
  });

  final int remaining;
  final int consumed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(15.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _CaloriesRow(label: '剩餘熱量', value: '$remaining kcal'),
          const SizedBox(height: 5.0),
          _CaloriesRow(label: '已攝取熱量', value: '$consumed kcal'),
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
        Text(label, style: const TextStyle(color: Colors.white)),
        Text(value, style: const TextStyle(color: Colors.white)),
      ],
    );
  } 
}
