/// Data models for GET/POST/PUT/DELETE /api/vehicle-owners.
const String ownerTypeOwn = 'OWN';
const String ownerTypeExternal = 'EXTERNAL';

const Map<String, String> ownerTypeLabels = {
  ownerTypeOwn: 'Own',
  ownerTypeExternal: 'External',
};

/// A vehicle owner row from GET /api/vehicle-owners.
class VehicleOwner {
  final int id;
  final String name;
  final String ownerType; // 'OWN' | 'EXTERNAL'

  const VehicleOwner({required this.id, required this.name, required this.ownerType});

  factory VehicleOwner.fromJson(Map<String, dynamic> json) => VehicleOwner(
        id: json['id'] as int,
        name: json['name'] as String? ?? '',
        ownerType: json['owner_type'] as String? ?? ownerTypeOwn,
      );

  @override
  bool operator ==(Object other) => other is VehicleOwner && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// DTO for POST /api/vehicle-owners.
class CreateOwnerDto {
  final String name;
  final String ownerType;

  const CreateOwnerDto({required this.name, required this.ownerType});

  Map<String, dynamic> toJson() => {'name': name, 'owner_type': ownerType};
}

/// DTO for PUT /api/vehicle-owners — renames cascade server-side.
class UpdateOwnerDto {
  final int id;
  final String? name;
  final String? ownerType;

  const UpdateOwnerDto({required this.id, this.name, this.ownerType});

  Map<String, dynamic> toJson() => {
        'id': id,
        if (name != null) 'name': name,
        if (ownerType != null) 'owner_type': ownerType,
      };
}
