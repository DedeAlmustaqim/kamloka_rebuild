class DocumentedPhoto {
  const DocumentedPhoto({
    required this.id,
    required this.locationId,
    required this.filePath,
    this.caption,
    this.capturedAt,
    this.latitude,
    this.longitude,
    this.address,
    required this.sortOrder,
    this.includeInReport = true,
    required this.createdAt,
  });

  final String id;
  final String locationId;
  final String filePath;
  final String? caption;
  final DateTime? capturedAt;
  final double? latitude;
  final double? longitude;
  final String? address;
  final int sortOrder;
  final bool includeInReport;
  final DateTime createdAt;

  Map<String, Object?> toMap() => {
        'id': id,
        'location_id': locationId,
        'file_path': filePath,
        'caption': caption,
        'captured_at': capturedAt?.toIso8601String(),
        'latitude': latitude,
        'longitude': longitude,
        'address': address,
        'sort_order': sortOrder,
        'include_in_report': includeInReport ? 1 : 0,
        'created_at': createdAt.toIso8601String(),
      };

  factory DocumentedPhoto.fromMap(Map<String, Object?> map) =>
      DocumentedPhoto(
        id: map['id'] as String,
        locationId: map['location_id'] as String,
        filePath: map['file_path'] as String,
        caption: map['caption'] as String?,
        capturedAt: map['captured_at'] == null
            ? null
            : DateTime.parse(map['captured_at'] as String),
        latitude: (map['latitude'] as num?)?.toDouble(),
        longitude: (map['longitude'] as num?)?.toDouble(),
        address: map['address'] as String?,
        sortOrder: (map['sort_order'] as num?)?.toInt() ?? 0,
        includeInReport: ((map['include_in_report'] as num?)?.toInt() ?? 1) == 1,
        createdAt: DateTime.parse(map['created_at'] as String),
      );
}
