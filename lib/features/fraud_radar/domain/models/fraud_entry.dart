class FraudEntry {
  const FraudEntry({
    required this.number,
    required this.category,
    required this.noticeDate,
    required this.sourceYear,
    required this.action,
    required this.yearsSeen,
    required this.timesSeen,
    required this.riskScore,
  });

  final String number;
  final String category;
  final String noticeDate;
  final int sourceYear;
  final String action;
  final List<int> yearsSeen;
  final int timesSeen;
  final int riskScore;

  factory FraudEntry.fromJson(Map<String, dynamic> json) {
    return FraudEntry(
      number: json['number'] as String,
      category: json['category'] as String,
      noticeDate: json['notice_date'] as String,
      sourceYear: json['source_year'] as int,
      action: json['action'] as String,
      yearsSeen: (json['years_seen'] as List<dynamic>)
          .map((value) => value as int)
          .toList(),
      timesSeen: json['times_seen'] as int,
      riskScore: json['risk_score'] as int,
    );
  }
}
