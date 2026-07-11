/// Vehicle type values accepted by the API (matches the web's VEHICLE_TYPES).
const String vehicleTypeCar = 'CAR';
const String vehicleTypeBus = 'BUS';
const String vehicleTypeTempoTraveller = 'TEMPO_TRAVELLER';
const String vehicleTypeTruck = 'TRUCK';
const String vehicleTypeContainer = 'CONTAINER';

class VehicleTypeOption {
  final String value;
  final String label;
  const VehicleTypeOption(this.value, this.label);
}

/// Mirrors VEHICLE_TYPES in ui-sslogistics/src/app/admin/vehicles/vehicles.types.ts.
const List<VehicleTypeOption> vehicleTypeOptions = [
  VehicleTypeOption(vehicleTypeCar, 'Car'),
  VehicleTypeOption(vehicleTypeBus, 'Bus'),
  VehicleTypeOption(vehicleTypeTempoTraveller, 'Tempo Traveller'),
  VehicleTypeOption(vehicleTypeTruck, 'Truck'),
  VehicleTypeOption(vehicleTypeContainer, 'Container'),
];

/// Vehicle types for which seating_capacity is meaningful.
const List<String> seatingCapacityVehicleTypes = [
  vehicleTypeCar,
  vehicleTypeBus,
  vehicleTypeTempoTraveller,
];

const int notesMaxLength = 500;

/// Booking status values accepted by the API.
const String statusConfirmed = 'confirmed';
const String statusCompleted = 'completed';
const String statusCancelled = 'cancelled';

const Map<String, String> tripBookingStatusLabels = {
  statusConfirmed: 'Confirmed',
  statusCompleted: 'Completed',
  statusCancelled: 'Cancelled',
};

String vehicleTypeLabel(String vehicleType) {
  for (final option in vehicleTypeOptions) {
    if (option.value == vehicleType) return option.label;
  }
  return vehicleType;
}

/// A trip booking row from GET /api/trip-bookings, including joined
/// vehicle/driver.
class TripBooking {
  final int id;
  final String customerName;
  final String? customerPhone;
  final String fromLocation;
  final String toLocation;
  final String startDate; // 'YYYY-MM-DD'
  final String? endDate; // 'YYYY-MM-DD'
  final String vehicleType;
  final int? seatingCapacity;
  final int? vehicleId;
  final int? driverId;
  final String status; // 'confirmed' | 'completed' | 'cancelled'
  final double? quotedAmount;
  final double advanceAmount;
  final String? notes;
  final int? externalTripId;
  final String? createdAt;
  final String? updatedAt;

  // Joined vehicle / driver info
  final String? vehicleNumber;
  final String? vehicleCompany;
  final String? vehicleModel;
  final String? driverName;
  final String? driverPhone;

  const TripBooking({
    required this.id,
    required this.customerName,
    this.customerPhone,
    required this.fromLocation,
    required this.toLocation,
    required this.startDate,
    this.endDate,
    required this.vehicleType,
    this.seatingCapacity,
    this.vehicleId,
    this.driverId,
    required this.status,
    this.quotedAmount,
    required this.advanceAmount,
    this.notes,
    this.externalTripId,
    this.createdAt,
    this.updatedAt,
    this.vehicleNumber,
    this.vehicleCompany,
    this.vehicleModel,
    this.driverName,
    this.driverPhone,
  });

  String get vehicleTypeLabelText => vehicleTypeLabel(vehicleType);
  String get statusLabel => tripBookingStatusLabels[status] ?? status;
  bool get showsSeatingCapacity =>
      seatingCapacityVehicleTypes.contains(vehicleType);

  factory TripBooking.fromJson(Map<String, dynamic> json) {
    final vehicle = json['vehicles'] as Map<String, dynamic>?;
    final driver = json['drivers'] as Map<String, dynamic>?;

    return TripBooking(
      id: json['id'] as int,
      customerName: json['customer_name'] as String? ?? '',
      customerPhone: json['customer_phone'] as String?,
      fromLocation: json['from_location'] as String? ?? '',
      toLocation: json['to_location'] as String? ?? '',
      startDate: json['start_date'] as String? ?? '',
      endDate: json['end_date'] as String?,
      vehicleType: json['vehicle_type'] as String? ?? vehicleTypeCar,
      seatingCapacity: json['seating_capacity'] as int?,
      vehicleId: json['vehicle_id'] as int?,
      driverId: json['driver_id'] as int?,
      status: json['status'] as String? ?? statusConfirmed,
      quotedAmount: (json['quoted_amount'] as num?)?.toDouble(),
      advanceAmount: (json['advance_amount'] as num?)?.toDouble() ?? 0,
      notes: json['notes'] as String?,
      externalTripId: json['external_trip_id'] as int?,
      createdAt: json['created_at'] as String?,
      updatedAt: json['updated_at'] as String?,
      vehicleNumber: vehicle?['vehicle_number'] as String?,
      vehicleCompany: vehicle?['company'] as String?,
      vehicleModel: vehicle?['model'] as String?,
      driverName: driver?['name'] as String?,
      driverPhone: driver?['phone'] as String?,
    );
  }
}

/// Filter-scoped counts computed server-side.
class TripBookingSummary {
  final int upcomingCount;
  final int overdueCount;
  final int completedCount;
  final int cancelledCount;

  const TripBookingSummary({
    required this.upcomingCount,
    required this.overdueCount,
    required this.completedCount,
    required this.cancelledCount,
  });

  factory TripBookingSummary.fromJson(Map<String, dynamic> json) =>
      TripBookingSummary(
        upcomingCount: json['upcomingCount'] as int? ?? 0,
        overdueCount: json['overdueCount'] as int? ?? 0,
        completedCount: json['completedCount'] as int? ?? 0,
        cancelledCount: json['cancelledCount'] as int? ?? 0,
      );
}

/// One page of bookings plus the (optional) summary.
class TripBookingListData {
  final List<TripBooking> bookings;
  final int total;
  final TripBookingSummary? summary;

  const TripBookingListData({
    required this.bookings,
    required this.total,
    this.summary,
  });
}

/// DTO for POST /api/trip-bookings.
class CreateTripBookingDto {
  final String customerName;
  final String? customerPhone;
  final String fromLocation;
  final String toLocation;
  final String startDate; // 'YYYY-MM-DD'
  final String? endDate; // 'YYYY-MM-DD'
  final String vehicleType;
  final int? seatingCapacity;
  final int? vehicleId;
  final int? driverId;
  final double? quotedAmount;
  final double? advanceAmount;
  final String? notes;

  const CreateTripBookingDto({
    required this.customerName,
    this.customerPhone,
    required this.fromLocation,
    required this.toLocation,
    required this.startDate,
    this.endDate,
    required this.vehicleType,
    this.seatingCapacity,
    this.vehicleId,
    this.driverId,
    this.quotedAmount,
    this.advanceAmount,
    this.notes,
  });

  Map<String, dynamic> toJson() => {
        'customer_name': customerName,
        'from_location': fromLocation,
        'to_location': toLocation,
        'start_date': startDate,
        'vehicle_type': vehicleType,
        if (customerPhone != null && customerPhone!.isNotEmpty)
          'customer_phone': customerPhone,
        if (endDate != null) 'end_date': endDate,
        if (seatingCapacity != null) 'seating_capacity': seatingCapacity,
        if (vehicleId != null) 'vehicle_id': vehicleId,
        if (driverId != null) 'driver_id': driverId,
        if (quotedAmount != null) 'quoted_amount': quotedAmount,
        if (advanceAmount != null) 'advance_amount': advanceAmount,
        if (notes != null && notes!.isNotEmpty) 'notes': notes,
      };
}

/// DTO for PUT /api/trip-bookings. Sends every editable field so cleared
/// optional values (phone, end date, seating capacity, vehicle, driver,
/// quoted amount, notes) are persisted as null — required fields
/// (customer/route/start date/vehicle type) are always sent with a value.
class UpdateTripBookingDto {
  final int id;
  final String customerName;
  final String? customerPhone;
  final String fromLocation;
  final String toLocation;
  final String startDate;
  final String? endDate;
  final String vehicleType;
  final int? seatingCapacity;
  final int? vehicleId;
  final int? driverId;
  final double? quotedAmount;
  final double advanceAmount;
  final String? notes;

  const UpdateTripBookingDto({
    required this.id,
    required this.customerName,
    this.customerPhone,
    required this.fromLocation,
    required this.toLocation,
    required this.startDate,
    this.endDate,
    required this.vehicleType,
    this.seatingCapacity,
    this.vehicleId,
    this.driverId,
    this.quotedAmount,
    required this.advanceAmount,
    this.notes,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'customer_name': customerName,
        'customer_phone': customerPhone,
        'from_location': fromLocation,
        'to_location': toLocation,
        'start_date': startDate,
        'end_date': endDate,
        'vehicle_type': vehicleType,
        'seating_capacity': seatingCapacity,
        'vehicle_id': vehicleId,
        'driver_id': driverId,
        'quoted_amount': quotedAmount,
        'advance_amount': advanceAmount,
        'notes': notes,
      };
}
