class CallCheckResult {
  const CallCheckResult({
    required this.number,
    required this.isFraud,
    required this.statusText,
    required this.reasonText,
    required this.category,
    required this.riskScore,
    required this.sourceYear,
    required this.action,
  });

  final String number;
  final bool isFraud;
  final String statusText;
  final String reasonText;
  final String? category;
  final int riskScore;
  final int? sourceYear;
  final String? action;
}
