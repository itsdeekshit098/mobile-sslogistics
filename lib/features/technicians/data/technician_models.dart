/// Data models for GET/POST/PUT/DELETE /api/technicians and /api/specializations.
const _phonePattern = r'^[6-9]\d{9}$';

bool isValidTechnicianPhone(String phone) => RegExp(_phonePattern).hasMatch(phone);

/// A technician row from GET /api/technicians.
class Technician {
  final int id;
  final String name;
  final String? phone;
  final String? location;
  final List<String> specializations;
  final bool isActive;

  const Technician({
    required this.id,
    required this.name,
    this.phone,
    this.location,
    required this.specializations,
    required this.isActive,
  });

  factory Technician.fromJson(Map<String, dynamic> json) => Technician(
        id: json['id'] as int,
        name: json['name'] as String? ?? '',
        phone: json['phone'] as String?,
        location: json['location'] as String?,
        specializations:
            (json['specializations'] as List?)?.whereType<String>().toList() ?? const [],
        isActive: json['is_active'] as bool? ?? true,
      );

  @override
  bool operator ==(Object other) => other is Technician && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// Option row from GET /api/specializations.
class SpecializationOption {
  final int id;
  final String name;

  const SpecializationOption({required this.id, required this.name});

  factory SpecializationOption.fromJson(Map<String, dynamic> json) => SpecializationOption(
        id: json['id'] as int,
        name: json['name'] as String? ?? '',
      );

  @override
  bool operator ==(Object other) => other is SpecializationOption && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// One page of technicians.
class TechnicianListData {
  final List<Technician> technicians;
  final int total;

  const TechnicianListData({required this.technicians, required this.total});
}

/// DTO for POST /api/technicians.
class CreateTechnicianDto {
  final String name;
  final String? phone;
  final String? location;
  final List<String> specializations;

  const CreateTechnicianDto({
    required this.name,
    this.phone,
    this.location,
    required this.specializations,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        if (phone != null && phone!.isNotEmpty) 'phone': phone,
        if (location != null && location!.isNotEmpty) 'location': location,
        'specializations': specializations,
      };
}

/// DTO for PUT /api/technicians — partial update; `isActive` doubles as the
/// activate/deactivate toggle.
class UpdateTechnicianDto {
  final int id;
  final String? name;
  final String? phone;
  final String? location;
  final List<String>? specializations;
  final bool? isActive;

  const UpdateTechnicianDto({
    required this.id,
    this.name,
    this.phone,
    this.location,
    this.specializations,
    this.isActive,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        if (name != null) 'name': name,
        if (phone != null) 'phone': phone,
        if (location != null) 'location': location,
        if (specializations != null) 'specializations': specializations,
        if (isActive != null) 'is_active': isActive,
      };
}
