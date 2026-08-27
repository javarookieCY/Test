import 'package:flutter/material.dart';
import '../../models/plan_item.dart';
import '../../utils/constants.dart';
import '../plans/plan_carousel.dart'; // We'll create this next

class StreakInfoRow extends StatelessWidget {
  const StreakInfoRow({super.key, required this.streakCount});

  final int streakCount;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const SizedBox(width: 15.0),
        Text('$streakCount', style: kGreyBoldText),
        const SizedBox(width: 2.0),
        const Icon(Icons.done, color: Colors.grey),
        const SizedBox(width: 15.0),
        Text(
          streakCount > 0 ? '天連續記錄' : '記錄食物來開始連續紀錄',
          style: kGreyBoldText,
        ),
      ],
    );
  }
}

// - 飲食計畫 -
class FoodStreakSection extends StatefulWidget {
  const FoodStreakSection({super.key, required this.plans});
  final List<PlanItem> plans;
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
      containerHeight = 120.0;
      buttonLook = const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.explore, color: Colors.white),
          SizedBox(width: 6.0),
          Text('探索計畫', style: TextStyle(color: Colors.white)),
        ],
      );
    }
    else{
      containerHeight = 0.0;
      buttonLook = const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.expand_more, color: Colors.white),
          SizedBox(width: 6.0),
          Text('展開', style: TextStyle(color: Colors.white)),
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
          child: containerHeight > 0
              ? PlanCarousel(plans: widget.plans) // Renamed from _PlanCarousel
              : null,
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
