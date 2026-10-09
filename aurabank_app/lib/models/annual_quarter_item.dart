class AnnualQuarterItem {
  final String id;
  final String title;
  final String subtitle;
  final double amount;
  final int settledCount;
  final bool isIncoming;

  const AnnualQuarterItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.settledCount,
    this.isIncoming = true,
  });
}
