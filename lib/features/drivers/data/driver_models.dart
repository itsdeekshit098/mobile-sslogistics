/// Data models for GET/POST/PUT/DELETE /api/drivers.
const _phonePattern = r'^[6-9]\d{9}$';

bool isValidDriverPhone(String phone) => RegExp(_phonePattern).hasMatch(phone);

/// A driver row from GET /api/drivers.
class Driver {
  final int id;
  final String name;
  final String? phone;
  final String? place;
  final String? dlNumber;
  final String? photoUrl;
  final bool isActive;

  const Driver({
    required this.id,
    required this.name,
    this.phone,
    this.place,
    this.dlNumber,
    this.photoUrl,
    required this.isActive,
  });

  factory Driver.fromJson(Map<String, dynamic> json) => Driver(
        id: json['id'] as int,
        name: json['name'] as String? ?? '',
        phone: json['phone'] as String?,
        place: json['place'] as String?,
        dlNumber: json['dl_number'] as String?,
        photoUrl: json['photo_url'] as String?,
        isActive: json['is_active'] as bool? ?? true,
      );

  @override
  bool operator ==(Object other) => other is Driver && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// One page of drivers.
class DriverListData {
  final List<Driver> drivers;
  final int total;

  const DriverListData({required this.drivers, required this.total});
}

/// DTO for POST /api/drivers.
class CreateDriverDto {
  final String name;
  final String? phone;
  final String? place;
  final String? dlNumber;
  final String? photoUrl;

  const CreateDriverDto({
    required this.name,
    this.phone,
    this.place,
    this.dlNumber,
    this.photoUrl,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        if (phone != null && phone!.isNotEmpty) 'phone': phone,
        if (place != null && place!.isNotEmpty) 'place': place,
        if (dlNumber != null && dlNumber!.isNotEmpty) 'dl_number': dlNumber,
        if (photoUrl != null && photoUrl!.isNotEmpty) 'photo_url': photoUrl,
      };
}

/// DTO for PUT /api/drivers — partial update; `isActive` doubles as the
/// activate/deactivate toggle.
class UpdateDriverDto {
  final int id;
  final String? name;
  final String? phone;
  final String? place;
  final String? dlNumber;
  final String? photoUrl;
  final bool? isActive;

  const UpdateDriverDto({
    required this.id,
    this.name,
    this.phone,
    this.place,
    this.dlNumber,
    this.photoUrl,
    this.isActive,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        if (name != null) 'name': name,
        if (phone != null) 'phone': phone,
        if (place != null) 'place': place,
        if (dlNumber != null) 'dl_number': dlNumber,
        if (photoUrl != null) 'photo_url': photoUrl,
        if (isActive != null) 'is_active': isActive,
      };
}
