class WorkEntry {
  final int? id;
  final DateTime date;
  final String customer;
  final double hours;

  WorkEntry({
    this.id,
    required this.date,
    required this.customer,
    required this.hours,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'date': date.toIso8601String(),
      'customer': customer,
      'hours': hours,
    };
  }

  factory WorkEntry.fromMap(Map<String, dynamic> map) {
    return WorkEntry(
      id: map['id'] as int?,
      date: DateTime.parse(map['date'] as String),
      customer: map['customer'] as String,
      hours: (map['hours'] as num).toDouble(),
    );
  }

  WorkEntry copyWith({
    int? id,
    DateTime? date,
    String? customer,
    double? hours,
  }) {
    return WorkEntry(
      id: id ?? this.id,
      date: date ?? this.date,
      customer: customer ?? this.customer,
      hours: hours ?? this.hours,
    );
  }
}
