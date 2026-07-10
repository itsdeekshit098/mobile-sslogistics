/// Data models for GET/POST/PUT /api/repair-records and its lookups.
const String repairCategoryElectrical = 'electrical';
const String repairCategoryMechanical = 'mechanical';

const Map<String, String> repairCategoryLabels = {
  repairCategoryElectrical: 'Electrical',
  repairCategoryMechanical: 'Mechanical',
};

const String repairStatusOpen = 'Open';
const String repairStatusClosed = 'Closed';

const String warrantyUnitMonths = 'months';
const String warrantyUnitYears = 'years';

/// Vendor row from GET /api/vendors, also embedded on a repair part.
class Vendor {
  final int id;
  final String name;
  final String? phone;
  final String? location;

  const Vendor({required this.id, required this.name, this.phone, this.location});

  factory Vendor.fromJson(Map<String, dynamic> json) => Vendor(
        id: json['id'] as int,
        name: json['name'] as String? ?? '',
        phone: json['phone'] as String?,
        location: json['location'] as String?,
      );

  @override
  bool operator ==(Object other) => other is Vendor && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// Technician row from GET /api/technicians.
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
        specializations: (json['specializations'] as List?)
                ?.whereType<String>()
                .toList() ??
            const [],
        isActive: json['is_active'] as bool? ?? true,
      );

  @override
  bool operator ==(Object other) => other is Technician && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// Option row from GET /api/part-options.
class PartOption {
  final int id;
  final String name;

  const PartOption({required this.id, required this.name});

  factory PartOption.fromJson(Map<String, dynamic> json) => PartOption(
        id: json['id'] as int,
        name: json['name'] as String? ?? '',
      );
}

/// Part attached to a repair record (from the `parts` embed, with vendor join).
class RepairPart {
  final int? id;
  final String partName;
  final int vendorId;
  final double cost;
  final String purchaseDate; // 'YYYY-MM-DD'
  final int warrantyDuration;
  final String warrantyDurationUnit; // 'months' | 'years'
  final String? warrantyExpiry; // server-computed, 'YYYY-MM-DD'
  final String? notes;
  final String? vendorName;
  final String? vendorPhone;
  final String? vendorLocation;

  const RepairPart({
    this.id,
    required this.partName,
    required this.vendorId,
    required this.cost,
    required this.purchaseDate,
    required this.warrantyDuration,
    required this.warrantyDurationUnit,
    this.warrantyExpiry,
    this.notes,
    this.vendorName,
    this.vendorPhone,
    this.vendorLocation,
  });

  factory RepairPart.fromJson(Map<String, dynamic> json) {
    final vendor = json['vendors'] as Map<String, dynamic>?;
    return RepairPart(
      id: json['id'] as int?,
      partName: json['part_name'] as String? ?? '',
      vendorId: json['vendor_id'] as int? ?? 0,
      cost: (json['cost'] as num?)?.toDouble() ?? 0,
      purchaseDate: json['purchase_date'] as String? ?? '',
      warrantyDuration: json['warranty_duration'] as int? ?? 0,
      warrantyDurationUnit:
          json['warranty_duration_unit'] as String? ?? warrantyUnitMonths,
      warrantyExpiry: json['warranty_expiry'] as String?,
      notes: json['notes'] as String?,
      vendorName: vendor?['name'] as String?,
      vendorPhone: vendor?['phone'] as String?,
      vendorLocation: vendor?['location'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        'part_name': partName,
        'vendor_id': vendorId,
        'cost': cost,
        'purchase_date': purchaseDate,
        'warranty_duration': warrantyDuration,
        'warranty_duration_unit': warrantyDurationUnit,
        if (notes != null && notes!.isNotEmpty) 'notes': notes,
      };
}

/// A repair record row from GET /api/repair-records, including joined
/// vehicle/technician info and nested parts.
class RepairRecord {
  final int id;
  final int vehicleId;
  final String repairDate; // ISO-8601
  final String category; // 'electrical' | 'mechanical'
  final List<String> issues;
  final String? description;
  final double cost;
  final String status; // 'Open' | 'Closed'
  final int? technicianId;
  final String? createdAt;
  final List<RepairPart> parts;

  // Joined vehicle info
  final String vehicleNumber;
  final String? vehicleCompany;
  final String? vehicleModel;

  // Joined technician info
  final String? technicianName;
  final String? technicianPhone;

  const RepairRecord({
    required this.id,
    required this.vehicleId,
    required this.repairDate,
    required this.category,
    required this.issues,
    this.description,
    required this.cost,
    required this.status,
    this.technicianId,
    this.createdAt,
    required this.parts,
    required this.vehicleNumber,
    this.vehicleCompany,
    this.vehicleModel,
    this.technicianName,
    this.technicianPhone,
  });

  bool get isOpen => status == repairStatusOpen;
  String get categoryLabel => repairCategoryLabels[category] ?? category;

  factory RepairRecord.fromJson(Map<String, dynamic> json) {
    final vehicle = json['vehicles'] as Map<String, dynamic>?;
    final technician = json['technicians'] as Map<String, dynamic>?;
    final rawParts = json['parts'] as List? ?? const [];

    return RepairRecord(
      id: json['id'] as int,
      vehicleId: json['vehicle_id'] as int? ?? 0,
      repairDate: json['repair_date'] as String? ?? '',
      category: json['category'] as String? ?? repairCategoryMechanical,
      issues: (json['issues'] as List?)?.whereType<String>().toList() ?? const [],
      description: json['description'] as String?,
      cost: (json['cost'] as num?)?.toDouble() ?? 0,
      status: json['status'] as String? ?? repairStatusOpen,
      technicianId: json['technician_id'] as int?,
      createdAt: json['created_at'] as String?,
      parts: rawParts
          .whereType<Map<String, dynamic>>()
          .map(RepairPart.fromJson)
          .toList(),
      vehicleNumber: vehicle?['vehicle_number'] as String? ?? '',
      vehicleCompany: vehicle?['company'] as String?,
      vehicleModel: vehicle?['model'] as String?,
      technicianName: technician?['name'] as String?,
      technicianPhone: technician?['phone'] as String?,
    );
  }
}

/// Filter-scoped aggregates computed server-side (RPC get_repair_records_summary).
class RepairSummary {
  final int totalCount;
  final double totalCost;
  final double electricalCost;
  final double mechanicalCost;
  final int openCount;
  final int closedCount;

  const RepairSummary({
    required this.totalCount,
    required this.totalCost,
    required this.electricalCost,
    required this.mechanicalCost,
    required this.openCount,
    required this.closedCount,
  });

  factory RepairSummary.fromJson(Map<String, dynamic> json) => RepairSummary(
        totalCount: json['totalCount'] as int? ?? 0,
        totalCost: (json['totalCost'] as num?)?.toDouble() ?? 0,
        electricalCost: (json['electricalCost'] as num?)?.toDouble() ?? 0,
        mechanicalCost: (json['mechanicalCost'] as num?)?.toDouble() ?? 0,
        openCount: json['openCount'] as int? ?? 0,
        closedCount: json['closedCount'] as int? ?? 0,
      );
}

/// One page of repair records plus the (optional, filter-scoped) summary.
class RepairListData {
  final List<RepairRecord> records;
  final int total;
  final RepairSummary? summary;

  const RepairListData({required this.records, required this.total, this.summary});
}

/// Filters accepted by GET /api/repair-records.
class RepairFilters {
  final int? vehicleId;
  final String? category;
  final String? status;
  final String? fromDate; // 'YYYY-MM-DD'
  final String? toDate; // 'YYYY-MM-DD'
  final int? technicianId;

  const RepairFilters({
    this.vehicleId,
    this.category,
    this.status,
    this.fromDate,
    this.toDate,
    this.technicianId,
  });

  bool get isEmpty =>
      vehicleId == null &&
      category == null &&
      status == null &&
      fromDate == null &&
      toDate == null &&
      technicianId == null;

  int get activeCount => [
        category,
        status,
        fromDate,
        toDate,
        technicianId,
      ].where((v) => v != null).length;

  RepairFilters copyWith({
    int? vehicleId,
    bool clearVehicle = false,
    String? category,
    bool clearCategory = false,
    String? status,
    bool clearStatus = false,
    String? fromDate,
    bool clearFromDate = false,
    String? toDate,
    bool clearToDate = false,
    int? technicianId,
    bool clearTechnician = false,
  }) {
    return RepairFilters(
      vehicleId: clearVehicle ? null : (vehicleId ?? this.vehicleId),
      category: clearCategory ? null : (category ?? this.category),
      status: clearStatus ? null : (status ?? this.status),
      fromDate: clearFromDate ? null : (fromDate ?? this.fromDate),
      toDate: clearToDate ? null : (toDate ?? this.toDate),
      technicianId: clearTechnician ? null : (technicianId ?? this.technicianId),
    );
  }

  Map<String, dynamic> toQueryParams() => {
        if (vehicleId != null) 'vehicle_id': vehicleId,
        if (category != null) 'category': category,
        if (status != null) 'status': status,
        if (fromDate != null) 'from_date': fromDate,
        if (toDate != null) 'to_date': toDate,
        if (technicianId != null) 'technician_id': technicianId,
      };
}

/// DTO for POST /api/repair-records. Status is forced to 'Open' server-side.
class CreateRepairDto {
  final int vehicleId;
  final String repairDate; // ISO-8601
  final String category;
  final List<String> issues;
  final String? description;
  final double cost;
  final int technicianId;
  final List<RepairPart> parts;

  const CreateRepairDto({
    required this.vehicleId,
    required this.repairDate,
    required this.category,
    required this.issues,
    this.description,
    required this.cost,
    required this.technicianId,
    this.parts = const [],
  });

  Map<String, dynamic> toJson() => {
        'vehicle_id': vehicleId,
        'repair_date': repairDate,
        'category': category,
        'issues': issues,
        'cost': cost,
        'technician_id': technicianId,
        if (description != null && description!.isNotEmpty)
          'description': description,
        if (parts.isNotEmpty) 'parts': parts.map((p) => p.toJson()).toList(),
      };
}

/// DTO for PUT /api/repair-records. vehicle_id/repair_date/category are not
/// editable. Sends every mutable field explicitly (mirrors
/// UpdateExternalTripDto) so cleared values persist and parts are fully synced.
class UpdateRepairDto {
  final int id;
  final String? description;
  final double cost;
  final int technicianId;
  final String status;
  final List<String> issues;
  final List<RepairPart> parts;

  const UpdateRepairDto({
    required this.id,
    this.description,
    required this.cost,
    required this.technicianId,
    required this.status,
    required this.issues,
    this.parts = const [],
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'description': description,
        'cost': cost,
        'technician_id': technicianId,
        'status': status,
        'issues': issues,
        'parts': parts.map((p) => p.toJson()).toList(),
      };
}
