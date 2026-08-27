import 'package:flutter/material.dart';
import '../../models/plan_item.dart';

class PlanDetailSheet extends StatelessWidget {
  const PlanDetailSheet({super.key, required this.plan});
  final PlanItem plan;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Color.fromARGB(255, 40, 40, 42),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.all(20.0),
          child: ListView(
            controller: scrollController, // 交給 DraggableScrollableSheet 控制，拖動跟捲動才不會打架
            children: [
              Text(plan.title,
                  style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Text(plan.description, style: const TextStyle(color: Colors.white70)),
              const SizedBox(height: 16),
              const Text('飲食規範', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              ...plan.dietRules.map((rule) => Padding(
                    padding: const EdgeInsets.only(bottom: 6.0),
                    child: Text('• $rule', style: const TextStyle(color: Colors.white70)),
                  )),
            ],
          ),
        );
      },
    );
  }
}
