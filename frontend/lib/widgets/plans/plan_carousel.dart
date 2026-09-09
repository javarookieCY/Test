import 'package:flutter/material.dart';
import '../../models/plan_item.dart';
import '../../utils/constants.dart';
import 'plan_detail_sheet.dart';

// - 方案飲食規範 -
class PlanCarousel extends StatefulWidget {
  const PlanCarousel({super.key, required this.plans});
  final List<PlanItem> plans;

  @override
  State<PlanCarousel> createState() => _PlanCarouselState();
}

class _PlanCarouselState extends State<PlanCarousel> {
  static const int _loopMultiplier = 10000; // 假裝很長的倍數

  late final PageController _controller;

  @override
  void initState() {
    super.initState();
    // 找一個中間值，且對 plans.length 取餘數要等於 1（對應圖2，index從0算）
    final middle = (widget.plans.length * _loopMultiplier) ~/ 2;
    final offsetToIndex1 = (1 - middle % widget.plans.length) % widget.plans.length;
    final initialPage = middle + offsetToIndex1;

    _controller = PageController(viewportFraction: 0.6, initialPage: initialPage);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PageView.builder(
      controller: _controller,
      itemCount: widget.plans.length * _loopMultiplier,
      itemBuilder: (context, rawIndex) {
        final index = rawIndex % widget.plans.length; // 換算回真正的資料
        final plan = widget.plans[index];
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6.0),
          child: GestureDetector(
            onTap: () => _showPlanDetail(context, plan),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8.0),
              child: Image.asset(
                plan.imagePath,
                fit: BoxFit.cover,
                // 圖片缺失時不要整片紅色錯誤，改顯示方案名稱
                errorBuilder: (context, error, stackTrace) => Container(
                  color: ElementColors.cardBg,
                  alignment: Alignment.center,
                  padding: const EdgeInsets.all(8),
                  child: Text(
                    plan.title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white70),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _showPlanDetail(BuildContext context, PlanItem plan) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => PlanDetailSheet(plan: plan),
    );
  }
}
