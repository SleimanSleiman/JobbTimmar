/// Represents a work report that contains multiple work entries.
/// Only ONE report can be active at a time.
class Report {
  final int? id;
  final DateTime createdAt;
  final DateTime? submittedAt;
  final bool isSubmitted;

  Report({
    this.id,
    required this.createdAt,
    this.submittedAt,
    this.isSubmitted = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'created_at': createdAt.toIso8601String(),
      'submitted_at': submittedAt?.toIso8601String(),
      'is_submitted': isSubmitted ? 1 : 0,
    };
  }

  factory Report.fromMap(Map<String, dynamic> map) {
    return Report(
      id: map['id'] as int?,
      createdAt: DateTime.parse(map['created_at'] as String),
      submittedAt: map['submitted_at'] != null 
          ? DateTime.parse(map['submitted_at'] as String) 
          : null,
      isSubmitted: (map['is_submitted'] as int) == 1,
    );
  }

  Report copyWith({
    int? id,
    DateTime? createdAt,
    DateTime? submittedAt,
    bool? isSubmitted,
  }) {
    return Report(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      submittedAt: submittedAt ?? this.submittedAt,
      isSubmitted: isSubmitted ?? this.isSubmitted,
    );
  }

  /// Creates a new empty active report
  factory Report.createNew() {
    return Report(
      createdAt: DateTime.now(),
      isSubmitted: false,
    );
  }
}
