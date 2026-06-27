class Vehicle {
  final int id;
  final String plateNumber;
  final double? expectedKml;
  final double? tankCapacity;
  final String? make;
  final String? model;

  const Vehicle({
    required this.id,
    required this.plateNumber,
    this.expectedKml,
    this.tankCapacity,
    this.make,
    this.model,
  });

  factory Vehicle.fromJson(Map<String, dynamic> json) {
    return Vehicle(
      id: json['id'] as int,
      // Handle both possible field names from the DB
      plateNumber:
          (json['vehicle_number'] ?? json['plate_number'] ?? json['registration_number'] ?? '') as String,
      expectedKml: (json['expected_kml'] as num?)?.toDouble(),
      tankCapacity: (json['tank_capacity'] as num?)?.toDouble(),
      make: json['make'] as String?,
      model: json['model'] as String?,
    );
  }

  /// Label shown in dropdowns / typeaheads
  String get displayName => plateNumber;

  @override
  bool operator ==(Object other) => other is Vehicle && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
