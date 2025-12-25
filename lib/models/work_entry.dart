class WorkEntry {
  final int? id;
  final DateTime date;
  final String customer;
  final double hours;
  final int? reportId; // Foreign key to report

  WorkEntry({
    this.id,
    required this.date,
    required this.customer,
    required this.hours,
    this.reportId,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'date': date.toIso8601String(),
      'customer': customer,
      'hours': hours,
      'report_id': reportId,
    };
  }

  factory WorkEntry.fromMap(Map<String, dynamic> map) {
    return WorkEntry(
      id: map['id'] as int?,
      date: DateTime.parse(map['date'] as String),
      customer: map['customer'] as String,
      hours: (map['hours'] as num).toDouble(),
      reportId: map['report_id'] as int?,
    );
  }

  WorkEntry copyWith({
    int? id,
    DateTime? date,
    String? customer,
    double? hours,
    int? reportId,
  }) {
    return WorkEntry(
      id: id ?? this.id,
      date: date ?? this.date,
      customer: customer ?? this.customer,
      hours: hours ?? this.hours,
      reportId: reportId ?? this.reportId,
    );
  }
}
