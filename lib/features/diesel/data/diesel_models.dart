/// Data model for a diesel fill record returned by GET /api/diesel-records.
class DieselRecord {
  final int id;
  final int vehicleId;
  final String driverName;
  final String fillDate; // ISO-8601 UTC timestamp
  final String fillType; // 'full' | 'partial'
  final double fuelLitres;
  final double pricePerL;
  final double currentOdo;
  final String? station;
  final String? paymentMethod;
  final String? receiptNumber;
  final String? notes;

  // Derived / calculated fields
  final double amount;
  final double? prevOdo;
  final double? distance;
  final double? kml;
  final double? devPct;
  final double? costPerKm;
  final double? cycleFuel;
  final double? cycleDistance;
  final int cycleId;
  final String cycleStatus; // 'open' | 'closed'
  final double? expectedKml;
  final double? tankCapacity; // from vehicle join — used for warnings
  final String verifiedBy;
  final String? createdAt;

  // Vehicle info from join
  final String vehiclePlate;

  const DieselRecord({
    required this.id,
    required this.vehicleId,
    required this.driverName,
    required this.fillDate,
    required this.fillType,
    required this.fuelLitres,
    required this.pricePerL,
    required this.currentOdo,
    this.station,
    this.paymentMethod,
    this.receiptNumber,
    this.notes,
    required this.amount,
    this.prevOdo,
    this.distance,
    this.kml,
    this.devPct,
    this.costPerKm,
    this.cycleFuel,
    this.cycleDistance,
    required this.cycleId,
    required this.cycleStatus,
    this.expectedKml,
    this.tankCapacity,
    required this.verifiedBy,
    this.createdAt,
    required this.vehiclePlate,
  });

  factory DieselRecord.fromJson(Map<String, dynamic> json) {
    // Vehicle plate may be in the record directly or nested
    final plate =
        (json['vehicle'] as Map<String, dynamic>?)?['vehicle_number'] as String? ??
        json['vehicle_number'] as String? ??
        json['plate_number'] as String? ??
        (json['vehicle'] as Map<String, dynamic>?)?['plate_number'] as String? ??
        '';

    final tank =
        (json['tank_capacity'] as num?)?.toDouble() ??
        ((json['vehicle'] as Map<String, dynamic>?)?['tank_capacity'] as num?)
            ?.toDouble();

    return DieselRecord(
      id: json['id'] as int,
      vehicleId: json['vehicle_id'] as int,
      driverName: json['driver_name'] as String? ?? '',
      fillDate: json['fill_date'] as String? ?? '',
      fillType: json['fill_type'] as String? ?? 'partial',
      fuelLitres: (json['fuel_litres'] as num?)?.toDouble() ?? 0,
      pricePerL: (json['price_per_l'] as num?)?.toDouble() ?? 0,
      currentOdo: (json['current_odo'] as num?)?.toDouble() ?? 0,
      station: json['station'] as String?,
      paymentMethod: json['payment_method'] as String?,
      receiptNumber: json['receipt_number'] as String?,
      notes: json['notes'] as String?,
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      prevOdo: (json['prev_odo'] as num?)?.toDouble(),
      distance: (json['distance'] as num?)?.toDouble(),
      kml: (json['kml'] as num?)?.toDouble(),
      devPct: (json['dev_pct'] as num?)?.toDouble(),
      costPerKm: (json['cost_per_km'] as num?)?.toDouble(),
      cycleFuel: (json['cycle_fuel'] as num?)?.toDouble(),
      cycleDistance: (json['cycle_distance'] as num?)?.toDouble(),
      cycleId: json['cycle_id'] as int? ?? 0,
      cycleStatus: json['cycle_status'] as String? ?? 'open',
      expectedKml: (json['expected_kml'] as num?)?.toDouble(),
      tankCapacity: tank,
      verifiedBy: json['verified_by'] as String? ?? '',
      createdAt: json['created_at'] as String?,
      vehiclePlate: plate,
    );
  }

  // ── Warning logic (mirrors web getRecordWarnings) ─────────────────────────
  bool get hasFuelOverfillWarning =>
      tankCapacity != null && tankCapacity! > 0 && fuelLitres > tankCapacity!;

  bool get hasLowFullFillWarning =>
      fillType == 'full' &&
      tankCapacity != null &&
      tankCapacity! > 0 &&
      fuelLitres > 0 &&
      fuelLitres < tankCapacity! * 0.3;

  bool get hasWarnings => hasFuelOverfillWarning || hasLowFullFillWarning;

  List<String> get warnings {
    final w = <String>[];
    if (hasFuelOverfillWarning) w.add('Fuel exceeds tank capacity');
    if (hasLowFullFillWarning) w.add('Low fuel for a full fill');
    return w;
  }
}

/// Paginated list result
class DieselListData {
  final List<DieselRecord> records;
  final int total;
  const DieselListData({required this.records, required this.total});
}

/// DTO for creating a new diesel record
class CreateDieselDto {
  final int vehicleId;
  final String driverName;
  final String fillDate; // ISO-8601
  final String fillType;
  final double fuelLitres;
  final double pricePerL;
  final double currentOdo;
  final String? station;
  final String? paymentMethod;
  final String? receiptNumber;
  final String? notes;

  const CreateDieselDto({
    required this.vehicleId,
    required this.driverName,
    required this.fillDate,
    required this.fillType,
    required this.fuelLitres,
    required this.pricePerL,
    required this.currentOdo,
    this.station,
    this.paymentMethod,
    this.receiptNumber,
    this.notes,
  });

  Map<String, dynamic> toJson() => {
        'vehicle_id': vehicleId,
        'driver_name': driverName,
        'fill_date': fillDate,
        'fill_type': fillType,
        'fuel_litres': fuelLitres,
        'price_per_l': pricePerL,
        'current_odo': currentOdo,
        if (station != null && station!.isNotEmpty) 'station': station,
        if (paymentMethod != null) 'payment_method': paymentMethod,
        if (receiptNumber != null && receiptNumber!.isNotEmpty)
          'receipt_number': receiptNumber,
        if (notes != null && notes!.isNotEmpty) 'notes': notes,
      };
}

/// DTO for editing an existing diesel record (only editable fields)
class UpdateDieselDto {
  final int id;
  final String? driverName;
  final double? fuelLitres;
  final double? pricePerL;
  final String? station;
  final String? paymentMethod;
  final String? receiptNumber;
  final String? notes;

  const UpdateDieselDto({
    required this.id,
    this.driverName,
    this.fuelLitres,
    this.pricePerL,
    this.station,
    this.paymentMethod,
    this.receiptNumber,
    this.notes,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        if (driverName != null) 'driver_name': driverName,
        if (fuelLitres != null) 'fuel_litres': fuelLitres,
        if (pricePerL != null) 'price_per_l': pricePerL,
        if (station != null) 'station': station,
        if (paymentMethod != null) 'payment_method': paymentMethod,
        if (receiptNumber != null) 'receipt_number': receiptNumber,
        if (notes != null) 'notes': notes,
      };
}
