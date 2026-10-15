class Trip {
  const Trip({
    required this.id,
    required this.title,
    required this.purpose,
    required this.startDate,
    required this.endDate,
    this.assignmentNumber,
    this.officerName,
    this.notes,
    this.status = 'draft',
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String title;
  final String purpose;
  final DateTime startDate;
  final DateTime endDate;
  final String? assignmentNumber;
  final String? officerName;
  final String? notes;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;

  Map<String, Object?> toMap() => {
        'id': id,
        'title': title,
        'purpose': purpose,
        'start_date': startDate.toIso8601String(),
        'end_date': endDate.toIso8601String(),
        'assignment_number': assignmentNumber,
        'officer_name': officerName,
        'notes': notes,
        'status': status,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  factory Trip.fromMap(Map<String, Object?> map) => Trip(
        id: map['id'] as String,
        title: map['title'] as String,
        purpose: map['purpose'] as String,
        startDate: DateTime.parse(map['start_date'] as String),
        endDate: DateTime.parse(map['end_date'] as String),
        assignmentNumber: map['assignment_number'] as String?,
        officerName: map['officer_name'] as String?,
        notes: map['notes'] as String?,
        status: map['status'] as String? ?? 'draft',
        createdAt: DateTime.parse(map['created_at'] as String),
        updatedAt: DateTime.parse(map['updated_at'] as String),
      );
}
