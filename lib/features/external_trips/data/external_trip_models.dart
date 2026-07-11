/// Trip type values accepted by the API.
const String tripTypeCompanyOncall = 'company_oncall';
const String tripTypeExternalUser = 'external_user';

const Map<String, String> tripTypeLabels = {
  tripTypeCompanyOncall: 'Company On-Call',
  tripTypeExternalUser: 'External Customer',
};

/// Cost item labels the API requires to be present on every trip.
const List<String> presetCostLabels = ['Diesel', 'Driver'];

const int notesMaxLength = 500;

/// One line item of the trip's cost breakdown (stored as JSON on the trip).
class CostItem {
  final String label;
  final double amount;

  const CostItem({required this.label, required this.amount});

  factory CostItem.fromJson(Map<String, dynamic> json) => CostItem(
        label: json['label'] as String? ?? '',
        amount: (json['amount'] as num?)?.toDouble() ?? 0,
      );

  Map<String, dynamic> toJson() => {'label': label, 'amount': amount};
}

/// A trip row from GET /api/external-trips, including joined vehicle/driver.
class ExternalTrip {
  final int id;
  final int vehicleId;
  final String tripType; // 'company_oncall' | 'external_user'
  final String? customerName;
  final String? customerPhone;
  final String? fromLocation;
  final String? toLocation;
  final String? startDate; // 'YYYY-MM-DD'
  final String? endDate; // 'YYYY-MM-DD'
  final int? driverId;
  final String? notes;
  final List<CostItem> costItems;
  final double totalCost;
  final double amountReceived;
  final String? createdAt;

  // Joined vehicle / driver info
  final String vehicleNumber;
  final String? vehicleCompany;
  final String? vehicleModel;
  final String? driverName;
  final String? driverPhone;

  const ExternalTrip({
    required this.id,
    required this.vehicleId,
    required this.tripType,
    this.customerName,
    this.customerPhone,
    this.fromLocation,
    this.toLocation,
    this.startDate,
    this.endDate,
    this.driverId,
    this.notes,
    required this.costItems,
    required this.totalCost,
    required this.amountReceived,
    this.createdAt,
    required this.vehicleNumber,
    this.vehicleCompany,
    this.vehicleModel,
    this.driverName,
    this.driverPhone,
  });

  double get profit => amountReceived - totalCost;

  String get tripTypeLabel => tripTypeLabels[tripType] ?? tripType;

  factory ExternalTrip.fromJson(Map<String, dynamic> json) {
    final vehicle = json['vehicles'] as Map<String, dynamic>?;
    final driver = json['drivers'] as Map<String, dynamic>?;
    final rawItems = json['cost_items'] as List? ?? const [];

    return ExternalTrip(
      id: json['id'] as int,
      vehicleId: json['vehicle_id'] as int? ?? 0,
      tripType: json['trip_type'] as String? ?? tripTypeCompanyOncall,
      customerName: json['customer_name'] as String?,
      customerPhone: json['customer_phone'] as String?,
      fromLocation: json['from_location'] as String?,
      toLocation: json['to_location'] as String?,
      startDate: json['start_date'] as String?,
      endDate: json['end_date'] as String?,
      driverId: json['driver_id'] as int?,
      notes: json['notes'] as String?,
      costItems: rawItems
          .whereType<Map<String, dynamic>>()
          .map(CostItem.fromJson)
          .toList(),
      totalCost: (json['total_cost'] as num?)?.toDouble() ?? 0,
      amountReceived: (json['amount_received'] as num?)?.toDouble() ?? 0,
      createdAt: json['created_at'] as String?,
      vehicleNumber: vehicle?['vehicle_number'] as String? ?? '',
      vehicleCompany: vehicle?['company'] as String?,
      vehicleModel: vehicle?['model'] as String?,
      driverName: driver?['name'] as String?,
      driverPhone: driver?['phone'] as String?,
    );
  }
}

/// Filter-scoped aggregates computed server-side.
class ExternalTripSummary {
  final double totalCost;
  final double totalReceived;
  final double totalProfit;
  final int count;

  const ExternalTripSummary({
    required this.totalCost,
    required this.totalReceived,
    required this.totalProfit,
    required this.count,
  });

  factory ExternalTripSummary.fromJson(Map<String, dynamic> json) =>
      ExternalTripSummary(
        totalCost: (json['totalCost'] as num?)?.toDouble() ?? 0,
        totalReceived: (json['totalReceived'] as num?)?.toDouble() ?? 0,
        totalProfit: (json['totalProfit'] as num?)?.toDouble() ?? 0,
        count: json['count'] as int? ?? 0,
      );
}

/// One page of trips plus the (optional) summary.
class ExternalTripListData {
  final List<ExternalTrip> trips;
  final int total;
  final ExternalTripSummary? summary;

  const ExternalTripListData({
    required this.trips,
    required this.total,
    this.summary,
  });
}

/// DTO for POST /api/external-trips.
class CreateExternalTripDto {
  final int vehicleId;
  final String tripType;
  final String? customerName;
  final String? customerPhone;
  final String? fromLocation;
  final String? toLocation;
  final String? startDate; // 'YYYY-MM-DD'
  final String? endDate; // 'YYYY-MM-DD'
  final int? driverId;
  final String? notes;
  final List<CostItem> costItems;
  final double amountReceived;

  /// When set, the server atomically marks the referenced trip booking
  /// 'completed' (and stamps its external_trip_id) once this trip is
  /// created — see /api/external-trips `booking_id`.
  final int? bookingId;

  const CreateExternalTripDto({
    required this.vehicleId,
    required this.tripType,
    this.customerName,
    this.customerPhone,
    this.fromLocation,
    this.toLocation,
    this.startDate,
    this.endDate,
    this.driverId,
    this.notes,
    required this.costItems,
    required this.amountReceived,
    this.bookingId,
  });

  Map<String, dynamic> toJson() => {
        'vehicle_id': vehicleId,
        'trip_type': tripType,
        'cost_items': costItems.map((c) => c.toJson()).toList(),
        'amount_received': amountReceived,
        if (customerName != null && customerName!.isNotEmpty)
          'customer_name': customerName,
        if (customerPhone != null && customerPhone!.isNotEmpty)
          'customer_phone': customerPhone,
        if (fromLocation != null && fromLocation!.isNotEmpty)
          'from_location': fromLocation,
        if (toLocation != null && toLocation!.isNotEmpty)
          'to_location': toLocation,
        if (startDate != null) 'start_date': startDate,
        if (endDate != null) 'end_date': endDate,
        if (driverId != null) 'driver_id': driverId,
        if (notes != null && notes!.isNotEmpty) 'notes': notes,
        if (bookingId != null) 'booking_id': bookingId,
      };
}

/// Values carried over from a confirmed trip booking being completed into a
/// trip — mirrors ExternalTripPrefill in
/// ui-sslogistics/src/components/externalTripsModal/externalTripsModal.types.ts.
class ExternalTripPrefill {
  final String? customerName;
  final String? customerPhone;
  final String? fromLocation;
  final String? toLocation;
  final String? startDate;
  final String? endDate;
  final int? vehicleId;
  /// Display label for [vehicleId] before the full vehicle list loads.
  final String? vehicleNumber;
  final int? driverId;
  /// Display label for [driverId] before the full driver list loads.
  final String? driverName;
  final String? driverPhone;
  /// Shown read-only in the form so the person entering final costs
  /// remembers what was agreed at booking time.
  final double? quotedAmount;
  final double? advanceAmount;

  const ExternalTripPrefill({
    this.customerName,
    this.customerPhone,
    this.fromLocation,
    this.toLocation,
    this.startDate,
    this.endDate,
    this.vehicleId,
    this.vehicleNumber,
    this.driverId,
    this.driverName,
    this.driverPhone,
    this.quotedAmount,
    this.advanceAmount,
  });
}

/// DTO for PUT /api/external-trips. Sends every editable field so cleared
/// values (driver, end date, customer info) are persisted as null —
/// vehicle_id and trip_type are not editable on the API.
class UpdateExternalTripDto {
  final int id;
  final String? customerName;
  final String? customerPhone;
  final String? fromLocation;
  final String? toLocation;
  final String? startDate;
  final String? endDate;
  final int? driverId;
  final String? notes;
  final List<CostItem> costItems;
  final double amountReceived;

  const UpdateExternalTripDto({
    required this.id,
    this.customerName,
    this.customerPhone,
    this.fromLocation,
    this.toLocation,
    this.startDate,
    this.endDate,
    this.driverId,
    this.notes,
    required this.costItems,
    required this.amountReceived,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'customer_name': customerName,
        'customer_phone': customerPhone,
        'from_location': fromLocation,
        'to_location': toLocation,
        'start_date': startDate,
        'end_date': endDate,
        'driver_id': driverId,
        'notes': notes,
        'cost_items': costItems.map((c) => c.toJson()).toList(),
        'amount_received': amountReceived,
      };
}

/// Lightweight driver row from GET /api/drivers (used by the driver picker).
class Driver {
  final int id;
  final String name;
  final String? phone;
  final bool isActive;

  const Driver({
    required this.id,
    required this.name,
    this.phone,
    required this.isActive,
  });

  factory Driver.fromJson(Map<String, dynamic> json) => Driver(
        id: json['id'] as int,
        name: json['name'] as String? ?? '',
        phone: json['phone'] as String?,
        isActive: json['is_active'] as bool? ?? true,
      );

  @override
  bool operator ==(Object other) => other is Driver && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
