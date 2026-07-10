/// Data models for GET/POST/PUT/DELETE /api/warranty.
const String warrantyStatusActive = 'active';
const String warrantyStatusExpiringSoon = 'expiring_soon';
const String warrantyStatusExpired = 'expired';

/// The `vehicles` join embedded on a warranty item.
class WarrantyVehicle {
  final int id;
  final String vehicleNumber;
  final String? company;
  final String? model;

  const WarrantyVehicle({
    required this.id,
    required this.vehicleNumber,
    this.company,
    this.model,
  });

  factory WarrantyVehicle.fromJson(Map<String, dynamic> json) => WarrantyVehicle(
        id: json['id'] as int? ?? 0,
        vehicleNumber: json['vehicle_number'] as String? ?? '',
        company: json['company'] as String?,
        model: json['model'] as String?,
      );
}

/// The `vendors` join embedded on a warranty item.
class WarrantyVendor {
  final int id;
  final String name;
  final String? phone;
  final String? location;

  const WarrantyVendor({required this.id, required this.name, this.phone, this.location});

  factory WarrantyVendor.fromJson(Map<String, dynamic> json) => WarrantyVendor(
        id: json['id'] as int,
        name: json['name'] as String? ?? '',
        phone: json['phone'] as String?,
        location: json['location'] as String?,
      );
}

class WarrantyItem {
  final int id;
  final int? repairRecordId;
  final int vehicleId;
  final String partName;
  final int? vendorId;
  final double cost;
  final String purchaseDate; // 'YYYY-MM-DD'
  final int warrantyDuration;
  final String warrantyDurationUnit; // 'months' | 'years'
  final String warrantyExpiry; // 'YYYY-MM-DD'
  final String? notes;
  final String createdAt;
  final String warrantyStatus;
  final WarrantyVendor? vendor;
  final WarrantyVehicle? vehicle;

  const WarrantyItem({
    required this.id,
    this.repairRecordId,
    required this.vehicleId,
    required this.partName,
    this.vendorId,
    required this.cost,
    required this.purchaseDate,
    required this.warrantyDuration,
    required this.warrantyDurationUnit,
    required this.warrantyExpiry,
    this.notes,
    required this.createdAt,
    required this.warrantyStatus,
    this.vendor,
    this.vehicle,
  });

  bool get isLinkedToRepair => repairRecordId != null;

  factory WarrantyItem.fromJson(Map<String, dynamic> json) {
    final vendorJson = json['vendors'] as Map<String, dynamic>?;
    final vehicleJson = json['vehicles'] as Map<String, dynamic>?;
    return WarrantyItem(
      id: json['id'] as int,
      repairRecordId: json['repair_record_id'] as int?,
      vehicleId: json['vehicle_id'] as int,
      partName: json['part_name'] as String? ?? '',
      vendorId: json['vendor_id'] as int?,
      cost: (json['cost'] as num?)?.toDouble() ?? 0,
      purchaseDate: json['purchase_date'] as String? ?? '',
      warrantyDuration: json['warranty_duration'] as int? ?? 0,
      warrantyDurationUnit: json['warranty_duration_unit'] as String? ?? 'months',
      warrantyExpiry: json['warranty_expiry'] as String? ?? '',
      notes: json['notes'] as String?,
      createdAt: json['created_at'] as String? ?? '',
      warrantyStatus: json['warranty_status'] as String? ?? warrantyStatusActive,
      vendor: vendorJson != null ? WarrantyVendor.fromJson(vendorJson) : null,
      vehicle: vehicleJson != null ? WarrantyVehicle.fromJson(vehicleJson) : null,
    );
  }
}

class WarrantyPage {
  final List<WarrantyItem> items;
  final int total;

  const WarrantyPage({required this.items, required this.total});
}

class WarrantyFilters {
  final int? vehicleId;
  final int? vendorId;
  final String? status; // active | expiring_soon | expired
  final DateTime? fromDate;
  final DateTime? toDate;
  final String search;

  const WarrantyFilters({
    this.vehicleId,
    this.vendorId,
    this.status,
    this.fromDate,
    this.toDate,
    this.search = '',
  });

  bool get hasActiveFilters =>
      vehicleId != null || vendorId != null || status != null || fromDate != null || toDate != null;

  int get activeCount =>
      [vehicleId, vendorId, status, fromDate, toDate].where((v) => v != null).length;

  WarrantyFilters copyWith({
    int? vehicleId,
    bool clearVehicleId = false,
    int? vendorId,
    bool clearVendorId = false,
    String? status,
    bool clearStatus = false,
    DateTime? fromDate,
    bool clearFromDate = false,
    DateTime? toDate,
    bool clearToDate = false,
    String? search,
  }) {
    return WarrantyFilters(
      vehicleId: clearVehicleId ? null : (vehicleId ?? this.vehicleId),
      vendorId: clearVendorId ? null : (vendorId ?? this.vendorId),
      status: clearStatus ? null : (status ?? this.status),
      fromDate: clearFromDate ? null : (fromDate ?? this.fromDate),
      toDate: clearToDate ? null : (toDate ?? this.toDate),
      search: search ?? this.search,
    );
  }
}

/// DTO for POST/PUT /api/warranty.
class WarrantyDto {
  final int? id;
  final int vehicleId;
  final String partName;
  final int vendorId;
  final double cost;
  final String purchaseDate; // 'YYYY-MM-DD'
  final int warrantyDuration;
  final String warrantyDurationUnit;
  final String? notes;
  final int? repairRecordId;

  const WarrantyDto({
    this.id,
    required this.vehicleId,
    required this.partName,
    required this.vendorId,
    required this.cost,
    required this.purchaseDate,
    required this.warrantyDuration,
    required this.warrantyDurationUnit,
    this.notes,
    this.repairRecordId,
  });

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        'vehicle_id': vehicleId,
        'part_name': partName,
        'vendor_id': vendorId,
        'cost': cost,
        'purchase_date': purchaseDate,
        'warranty_duration': warrantyDuration,
        'warranty_duration_unit': warrantyDurationUnit,
        if (notes != null && notes!.isNotEmpty) 'notes': notes,
        if (repairRecordId != null) 'repair_record_id': repairRecordId,
      };
}
