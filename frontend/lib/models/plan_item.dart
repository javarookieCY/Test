class PlanItem {
  const PlanItem({
    required this.title,
    required this.imagePath,
    required this.description,
    required this.dietRules,
  });
  final String title;
  final String imagePath;
  final String description;
  final List<String> dietRules;
}
