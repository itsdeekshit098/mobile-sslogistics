class FleetVehicle {
  final int id;
  final String vehicleNumber;
  final String vehicleType;
  final int? seatingCapacity;
  final String? company;
  final String? model;
  final String status;
  final String? lastServiceDate;
  final String? rcUrl;
  final String? insuranceUrl;
  final String? fcUrl;
  final String? permitUrl;
  final String? pollutionUrl;
  final String? taxUrl;
  final String? insuranceStartDate;
  final String? insuranceEndDate;
  final String? fcStartDate;
  final String? fcEndDate;
  /// active/expiring_soon/expired, computed server-side from *_end_date; null when no date is set.
  final String? fcStatus;
  final String? insuranceStatus;
  final double? expectedKml;
  final double? tankCapacity;
  final String? fuelType;
  final String? logoUrl;
  final String? truckType;
  final String? containerLength;
  final String? axleType;
  final String? containerBodyType;
  final String? ownerType;
  final String? ownerName;
  final String? createdAt;
  final String? updatedAt;

  const FleetVehicle({
    required this.id,
    required this.vehicleNumber,
    required this.vehicleType,
    this.seatingCapacity,
    this.company,
    this.model,
    required this.status,
    this.lastServiceDate,
    this.rcUrl,
    this.insuranceUrl,
    this.fcUrl,
    this.permitUrl,
    this.pollutionUrl,
    this.taxUrl,
    this.insuranceStartDate,
    this.insuranceEndDate,
    this.fcStartDate,
    this.fcEndDate,
    this.fcStatus,
    this.insuranceStatus,
    this.expectedKml,
    this.tankCapacity,
    this.fuelType,
    this.logoUrl,
    this.truckType,
    this.containerLength,
    this.axleType,
    this.containerBodyType,
    this.ownerType,
    this.ownerName,
    this.createdAt,
    this.updatedAt,
  });

  factory FleetVehicle.fromJson(Map<String, dynamic> json) {
    return FleetVehicle(
      id: json['id'] as int,
      vehicleNumber: json['vehicle_number'] as String? ?? '',
      vehicleType: json['vehicle_type'] as String? ?? '',
      seatingCapacity: (json['seating_capacity'] as num?)?.toInt(),
      company: json['company'] as String?,
      model: json['model'] as String?,
      status: json['status'] as String? ?? 'Active',
      lastServiceDate: json['last_service_date'] as String?,
      rcUrl: json['rc_url'] as String?,
      insuranceUrl: json['insurance_url'] as String?,
      fcUrl: json['fc_url'] as String?,
      permitUrl: json['permit_url'] as String?,
      pollutionUrl: json['pollution_url'] as String?,
      taxUrl: json['tax_url'] as String?,
      insuranceStartDate: json['insurance_start_date'] as String?,
      insuranceEndDate: json['insurance_end_date'] as String?,
      fcStartDate: json['fc_start_date'] as String?,
      fcEndDate: json['fc_end_date'] as String?,
      fcStatus: json['fc_status'] as String?,
      insuranceStatus: json['insurance_status'] as String?,
      expectedKml: (json['expected_kml'] as num?)?.toDouble(),
      tankCapacity: (json['tank_capacity'] as num?)?.toDouble(),
      fuelType: json['fuel_type'] as String?,
      logoUrl:
          json['logo_url'] as String? ??
          json['image_url'] as String? ??
          json['vehicle_logo'] as String? ??
          json['vehicle_image'] as String? ??
          json['photo_url'] as String?,
      truckType: json['truck_type'] as String?,
      containerLength: json['container_length'] as String?,
      axleType: json['axle_type'] as String?,
      containerBodyType: json['container_body_type'] as String?,
      ownerType: json['owner_type'] as String?,
      ownerName: json['owner_name'] as String?,
      createdAt: json['created_at'] as String?,
      updatedAt: json['updated_at'] as String?,
    );
  }

  String? documentPath(String key) {
    switch (key) {
      case 'rc_url':
        return rcUrl;
      case 'fc_url':
        return fcUrl;
      case 'insurance_url':
        return insuranceUrl;
      case 'permit_url':
        return permitUrl;
      case 'pollution_url':
        return pollutionUrl;
      case 'tax_url':
        return taxUrl;
    }
    return null;
  }

  String? dateFieldValue(String key) {
    switch (key) {
      case 'insurance_start_date':
        return insuranceStartDate;
      case 'insurance_end_date':
        return insuranceEndDate;
      case 'fc_start_date':
        return fcStartDate;
      case 'fc_end_date':
        return fcEndDate;
    }
    return null;
  }

  FleetVehicle copyWithDate(String key, String? value) {
    return FleetVehicle(
      id: id,
      vehicleNumber: vehicleNumber,
      vehicleType: vehicleType,
      seatingCapacity: seatingCapacity,
      company: company,
      model: model,
      status: status,
      lastServiceDate: lastServiceDate,
      rcUrl: rcUrl,
      insuranceUrl: insuranceUrl,
      fcUrl: fcUrl,
      permitUrl: permitUrl,
      pollutionUrl: pollutionUrl,
      taxUrl: taxUrl,
      insuranceStartDate: key == 'insurance_start_date' ? value : insuranceStartDate,
      insuranceEndDate: key == 'insurance_end_date' ? value : insuranceEndDate,
      fcStartDate: key == 'fc_start_date' ? value : fcStartDate,
      fcEndDate: key == 'fc_end_date' ? value : fcEndDate,
      // Statuses are server-computed from *_end_date — a local date patch
      // can't recompute them, so they're intentionally dropped here; the
      // caller should refetch the vehicle list to pick up fresh values.
      fcStatus: null,
      insuranceStatus: null,
      expectedKml: expectedKml,
      tankCapacity: tankCapacity,
      fuelType: fuelType,
      logoUrl: logoUrl,
      truckType: truckType,
      containerLength: containerLength,
      axleType: axleType,
      containerBodyType: containerBodyType,
      ownerType: ownerType,
      ownerName: ownerName,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  /// Updates the document path for [key]. When the document is being removed
  /// (`path == null`) for insurance/FC, the paired validity dates are cleared
  /// too — an uploaded-then-deleted document shouldn't leave a stale expiry
  /// date behind (mirrors the server, which clears the same columns on
  /// `DELETE /api/vehicles/documents`).
  FleetVehicle copyWithDocument(String key, String? path) {
    final clearInsuranceDates = path == null && key == 'insurance_url';
    final clearFcDates = path == null && key == 'fc_url';
    return FleetVehicle(
      id: id,
      vehicleNumber: vehicleNumber,
      vehicleType: vehicleType,
      seatingCapacity: seatingCapacity,
      company: company,
      model: model,
      status: status,
      lastServiceDate: lastServiceDate,
      rcUrl: key == 'rc_url' ? path : rcUrl,
      insuranceUrl: key == 'insurance_url' ? path : insuranceUrl,
      fcUrl: key == 'fc_url' ? path : fcUrl,
      permitUrl: key == 'permit_url' ? path : permitUrl,
      pollutionUrl: key == 'pollution_url' ? path : pollutionUrl,
      taxUrl: key == 'tax_url' ? path : taxUrl,
      insuranceStartDate: clearInsuranceDates ? null : insuranceStartDate,
      insuranceEndDate: clearInsuranceDates ? null : insuranceEndDate,
      fcStartDate: clearFcDates ? null : fcStartDate,
      fcEndDate: clearFcDates ? null : fcEndDate,
      // Server-computed — stale after a doc/date change; the caller (see
      // vehicle_documents_sheet's onChanged) refreshes the list to refetch.
      fcStatus: clearFcDates ? null : fcStatus,
      insuranceStatus: clearInsuranceDates ? null : insuranceStatus,
      expectedKml: expectedKml,
      tankCapacity: tankCapacity,
      fuelType: fuelType,
      logoUrl: logoUrl,
      truckType: truckType,
      containerLength: containerLength,
      axleType: axleType,
      containerBodyType: containerBodyType,
      ownerType: ownerType,
      ownerName: ownerName,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}

class VehicleStats {
  final int total;
  final int active;
  final int maintenance;
  final int idle;

  const VehicleStats({
    this.total = 0,
    this.active = 0,
    this.maintenance = 0,
    this.idle = 0,
  });

  factory VehicleStats.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const VehicleStats();
    return VehicleStats(
      total: (json['total'] as num?)?.toInt() ?? 0,
      active: (json['active'] as num?)?.toInt() ?? 0,
      maintenance: (json['maintenance'] as num?)?.toInt() ?? 0,
      idle: (json['idle'] as num?)?.toInt() ?? 0,
    );
  }
}

class VehicleListData {
  final List<FleetVehicle> vehicles;
  final int total;
  final VehicleStats stats;

  const VehicleListData({
    required this.vehicles,
    required this.total,
    required this.stats,
  });
}

class VehiclePayload {
  final int? id;
  final String vehicleNumber;
  final String vehicleType;
  final int? seatingCapacity;
  final String? company;
  final String? model;
  final String status;
  final String? lastServiceDate;
  final double? expectedKml;
  final double? tankCapacity;
  final String fuelType;
  final String? truckType;
  final String? containerLength;
  final String? axleType;
  final String? containerBodyType;
  final String ownerType;
  final String ownerName;

  const VehiclePayload({
    this.id,
    required this.vehicleNumber,
    required this.vehicleType,
    this.seatingCapacity,
    this.company,
    this.model,
    required this.status,
    this.lastServiceDate,
    this.expectedKml,
    this.tankCapacity,
    required this.fuelType,
    this.truckType,
    this.containerLength,
    this.axleType,
    this.containerBodyType,
    required this.ownerType,
    required this.ownerName,
  });

  Map<String, dynamic> toJson() => {
    if (id != null) 'id': id,
    'vehicle_number': vehicleNumber.trim(),
    'vehicle_type': vehicleType,
    'seating_capacity': seatingCapacity,
    'company': company?.trim(),
    'model': model?.trim(),
    'status': status,
    'last_service_date': lastServiceDate,
    'expected_kml': expectedKml,
    'tank_capacity': tankCapacity,
    'fuel_type': fuelType,
    'truck_type': truckType,
    'container_length': containerLength,
    'axle_type': axleType,
    'container_body_type': containerBodyType,
    'owner_type': ownerType,
    'owner_name': ownerName.trim(),
  };
}

class VehicleOwner {
  final int id;
  final String name;
  final String ownerType;

  const VehicleOwner({
    required this.id,
    required this.name,
    required this.ownerType,
  });

  factory VehicleOwner.fromJson(Map<String, dynamic> json) {
    return VehicleOwner(
      id: json['id'] as int,
      name: json['name'] as String? ?? '',
      ownerType: json['owner_type'] as String? ?? '',
    );
  }
}

/// Optional start/end date field keys associated with a document type
/// (e.g. Insurance and FC have validity periods; other documents don't).
class DocumentDateFields {
  final String startKey;
  final String endKey;

  const DocumentDateFields({required this.startKey, required this.endKey});
}

class VehicleDocumentType {
  final String key;
  final String label;
  final DocumentDateFields? dateFields;

  const VehicleDocumentType(this.key, this.label, {this.dateFields});
}

const vehicleTypes = ['CAR', 'BUS', 'TEMPO_TRAVELLER', 'TRUCK', 'CONTAINER'];
const vehicleStatuses = ['Active', 'Maintenance', 'Idle'];
const fuelTypes = [
  'DIESEL',
  'PETROL',
  'CNG',
  'LPG',
  'ELECTRIC',
  'HYBRID',
  'LNG',
];

/// Human-readable label for a fuel type (acronyms stay uppercase).
String fuelTypeLabel(String value) {
  switch (value.toUpperCase()) {
    case 'CNG':
    case 'LPG':
    case 'LNG':
      return value.toUpperCase();
    default:
      return enumLabel(value);
  }
}

/// Vehicle types that require a mandatory seating capacity.
const seatingCapacityRequiredTypes = ['CAR', 'BUS', 'TEMPO_TRAVELLER'];
const truckTypes = [
  'MINI_TRUCK',
  'PICKUP_TRUCK',
  'LCV',
  'MCV',
  'HCV',
  'TIPPER_TRUCK',
  'TANKER',
  'TRAILER_TRUCK',
];
const containerLengths = [
  '19_FT',
  '20_FT',
  '22_FT',
  '24_FT',
  '32_FT',
  '40_FT',
];
const axleTypes = ['SINGLE_AXLE', 'MULTI_AXLE', 'TRAILER'];
const containerBodyTypes = ['CLOSED', 'FLATBED_OPEN'];

/// Matches the check constraint on `vehicles.owner_type` / `vehicle_owners.owner_type`.
const ownerTypes = ['OWN', 'EXTERNAL'];

/// Human-readable label for an owner type (e.g. "EXTERNAL" -> "External").
String ownerTypeLabel(String value) {
  switch (value) {
    case 'OWN':
      return 'Own';
    case 'EXTERNAL':
      return 'External';
    default:
      return value.isEmpty ? '-' : enumLabel(value);
  }
}

/// Formats an uppercase enum value like "TEMPO_TRAVELLER" → "Tempo Traveller".
String enumLabel(String value) {
  return value
      .split('_')
      .map(
        (w) => w.isEmpty
            ? ''
            : w[0].toUpperCase() + w.substring(1).toLowerCase(),
      )
      .join(' ');
}

/// Human-readable label for a truck type.
String truckTypeLabel(String value) {
  switch (value) {
    case 'MINI_TRUCK':
      return 'Mini Truck';
    case 'PICKUP_TRUCK':
      return 'Pickup Truck';
    case 'LCV':
      return 'Light Commercial Vehicle (LCV)';
    case 'MCV':
      return 'Medium Commercial Vehicle (MCV)';
    case 'HCV':
      return 'Heavy Commercial Vehicle (HCV)';
    case 'TIPPER_TRUCK':
      return 'Tipper Truck';
    case 'TANKER':
      return 'Tanker';
    case 'TRAILER_TRUCK':
      return 'Trailer Truck';
    default:
      return enumLabel(value);
  }
}

/// Human-readable label for an axle type.
String axleTypeLabel(String value) {
  switch (value) {
    case 'SINGLE_AXLE':
      return 'Single Axle (SXL)';
    case 'MULTI_AXLE':
      return 'Multi Axle (MXL)';
    case 'TRAILER':
      return 'Trailer';
    default:
      return enumLabel(value);
  }
}

/// Human-readable label for a container body type.
String containerBodyTypeLabel(String value) {
  switch (value) {
    case 'CLOSED':
      return 'Closed Container';
    case 'FLATBED_OPEN':
      return 'Flatbed (Open)';
    default:
      return enumLabel(value);
  }
}

/// Human-readable label for a container length.
String containerLengthLabel(String value) =>
    value.replaceAll('_FT', ' ft').replaceAll('_', ' ');

/// Returns the human-readable label for a vehicle type.
String vehicleTypeLabel(String type) {
  switch (type.toUpperCase()) {
    case 'CAR':
      return 'Car';
    case 'BUS':
      return 'Bus';
    case 'TEMPO_TRAVELLER':
      return 'Tempo Traveller';
    case 'TRUCK':
      return 'Truck';
    case 'CONTAINER':
      return 'Container';
    default:
      return type;
  }
}

/// Returns a formatted sub-detail string for a vehicle card.
///
/// - CAR / BUS / TEMPO_TRAVELLER → "5-Seater" or "—"
/// - TRUCK                       → truck_type label or "—"
/// - CONTAINER                   → "32 ft - Single Axle (SXL) - Closed Container" or "—"
String vehicleSubDetail(FleetVehicle v) {
  switch (v.vehicleType.toUpperCase()) {
    case 'CAR':
    case 'BUS':
    case 'TEMPO_TRAVELLER':
      return v.seatingCapacity != null
          ? '${v.seatingCapacity}-Seater'
          : '—';
    case 'TRUCK':
      return v.truckType != null ? truckTypeLabel(v.truckType!) : '—';
    case 'CONTAINER':
      final parts = [
        if (v.containerLength != null) containerLengthLabel(v.containerLength!),
        if (v.axleType != null) axleTypeLabel(v.axleType!),
        if (v.containerBodyType != null)
          containerBodyTypeLabel(v.containerBodyType!),
      ];
      return parts.isEmpty ? '—' : parts.join(' - ');
    default:
      return '—';
  }
}
const vehicleDocumentTypes = [
  VehicleDocumentType('rc_url', 'Registration (RC)'),
  VehicleDocumentType(
    'fc_url',
    'Fitness Certificate (FC)',
    dateFields: DocumentDateFields(
      startKey: 'fc_start_date',
      endKey: 'fc_end_date',
    ),
  ),
  VehicleDocumentType(
    'insurance_url',
    'Insurance',
    dateFields: DocumentDateFields(
      startKey: 'insurance_start_date',
      endKey: 'insurance_end_date',
    ),
  ),
  VehicleDocumentType('permit_url', 'Permit'),
  VehicleDocumentType('pollution_url', 'Pollution (PUC)'),
  VehicleDocumentType('tax_url', 'Road Tax'),
];
