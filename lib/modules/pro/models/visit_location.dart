class VisitLocation {
  const VisitLocation({
    required this.id,
    required this.tripId,
    required this.name,
    this.address,
    this.latitude,
    this.longitude,
    this.visitedAt,
    this.notes,
    required this.sortOrder,
    required this.createdAt,
  });

  final String id;
  final String tripId;
  final String name;
  final String? address;
  final double? latitude;
  final double? longitude;
  final DateTime? visitedAt;
  final String? notes;
  final int sortOrder;
  final DateTime createdAt;

  Map<String, Object?> toMap() => {
        'id': id,
        'trip_id': tripId,
        'name': name,
        'address': address,
        'latitude': latitude,
        'longitude': longitude,
        'visited_at': visitedAt?.toIso8601String(),
        'notes': notes,
        'sort_order': sortOrder,
        'created_at': createdAt.toIso8601String(),
      };

  factory VisitLocation.fromMap(Map<String, Object?> map) => VisitLocation(
        id: map['id'] as String,
        tripId: map['trip_id'] as String,
        name: map['name'] as String,
        address: map['address'] as String?,
        latitude: (map['latitude'] as num?)?.toDouble(),
        longitude: (map['longitude'] as num?)?.toDouble(),
        visitedAt: map['visited_at'] == null
            ? null
            : DateTime.parse(map['visited_at'] as String),
        notes: map['notes'] as String?,
        sortOrder: (map['sort_order'] as num?)?.toInt() ?? 0,
        createdAt: DateTime.parse(map['created_at'] as String),
      );
}
