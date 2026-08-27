import 'package:flutter/material.dart';
import '../../utils/constants.dart';

// - 頁首 -
class HomeHeader extends StatelessWidget {
  const HomeHeader({super.key, required this.dateLabel});
  final String dateLabel;

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
        Padding(
          padding: const EdgeInsets.all(15.0),
          child: Row(
            children: [Text(dateLabel, style: kTitleText)],
          ),
        ),
      ],
    );
  }
}
