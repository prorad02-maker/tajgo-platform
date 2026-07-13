class DeliveryMapIntelligence {
  const DeliveryMapIntelligence({
    required this.targetLabel,
    required this.actionHint,
    required this.note,
    required this.showConfirmationCode,
    required this.isPickup,
  });

  final String targetLabel;
  final String actionHint;
  final String note;
  final bool showConfirmationCode;
  final bool isPickup;
}
