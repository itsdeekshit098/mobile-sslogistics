import '../../../shared/data/bank_account_models.dart';
import '../../../shared/state/list_filters.dart';
import '../../../shared/utils/json_parse.dart';

const List<String> kSeatingCapacityTypes = ['CAR', 'BUS', 'TEMPO_TRAVELLER'];

const List<Map<String, String>> kVehicleTypes = [
  {'value': 'CAR', 'label': 'Car'},
  {'value': 'BUS', 'label': 'Bus'},
  {'value': 'TEMPO_TRAVELLER', 'label': 'Tempo Traveller'},
  {'value': 'TRUCK', 'label': 'Truck'},
  {'value': 'CONTAINER', 'label': 'Container'},
];

const List<Map<String, String>> kTruckTypes = [
  {'value': 'MINI_TRUCK', 'label': 'Mini Truck'},
  {'value': 'PICKUP_TRUCK', 'label': 'Pickup Truck'},
  {'value': 'LCV', 'label': 'Light Commercial Vehicle (LCV)'},
  {'value': 'MCV', 'label': 'Medium Commercial Vehicle (MCV)'},
  {'value': 'HCV', 'label': 'Heavy Commercial Vehicle (HCV)'},
  {'value': 'TIPPER_TRUCK', 'label': 'Tipper Truck'},
  {'value': 'TANKER', 'label': 'Tanker'},
  {'value': 'TRAILER_TRUCK', 'label': 'Trailer Truck'},
];

const List<Map<String, String>> kContainerLengths = [
  {'value': '19_FT', 'label': '19 ft'},
  {'value': '20_FT', 'label': '20 ft'},
  {'value': '22_FT', 'label': '22 ft'},
  {'value': '24_FT', 'label': '24 ft'},
  {'value': '32_FT', 'label': '32 ft'},
  {'value': '40_FT', 'label': '40 ft'},
];

const List<Map<String, String>> kAxleTypes = [
  {'value': 'SINGLE_AXLE', 'label': 'Single Axle (SXL)'},
  {'value': 'MULTI_AXLE', 'label': 'Multi Axle (MXL)'},
  {'value': 'TRAILER', 'label': 'Trailer'},
];

const List<Map<String, String>> kContainerBodyTypes = [
  {'value': 'CLOSED', 'label': 'Closed Container'},
  {'value': 'FLATBED_OPEN', 'label': 'Flatbed (Open)'},
];

String vehicleTypeLabel(String value) => _labelFrom(kVehicleTypes, value);
String truckTypeLabel(String? value) => value == null ? '' : _labelFrom(kTruckTypes, value);
String containerLengthLabel(String? value) =>
    value == null ? '' : _labelFrom(kContainerLengths, value);
String axleTypeLabel(String? value) => value == null ? '' : _labelFrom(kAxleTypes, value);
String containerBodyTypeLabel(String? value) =>
    value == null ? '' : _labelFrom(kContainerBodyTypes, value);

String _labelFrom(List<Map<String, String>> options, String value) {
  for (final o in options) {
    if (o['value'] == value) return o['label']!;
  }
  return value;
}

/// Looks up an option row by its `value`, or null if [value] is null or
/// unmatched — used to pre-select a picker sheet without depending on
/// `Iterable.firstOrNull` (package:collection, not a direct dependency here).
Map<String, String>? findOption(List<Map<String, String>> options, String? value) {
  if (value == null) return null;
  for (final o in options) {
    if (o['value'] == value) return o;
  }
  return null;
}

/// One line describing exactly what a deployment is — "Bus · 43-seater",
/// "Container · 32 ft · Closed Container · Multi Axle (MXL)".
String describeDeployment(ClientDeployment d) {
  final parts = <String>[vehicleTypeLabel(d.vehicleType)];
  if (d.seatingCapacity != null) parts.add('${d.seatingCapacity}-seater');
  final truck = truckTypeLabel(d.truckType);
  if (truck.isNotEmpty) parts.add(truck);
  final length = containerLengthLabel(d.containerLength);
  if (length.isNotEmpty) parts.add(length);
  final body = containerBodyTypeLabel(d.containerBodyType);
  if (body.isNotEmpty) parts.add(body);
  final axle = axleTypeLabel(d.axleType);
  if (axle.isNotEmpty) parts.add(axle);
  return parts.join(' · ');
}

/// "4 × Bus · 2 × Container" from a fleet-mix count map.
String describeFleetMix(Map<String, int> mix) {
  final entries = mix.entries.where((e) => e.value > 0).toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  if (entries.isEmpty) return '';
  return entries.map((e) => '${e.value} × ${vehicleTypeLabel(e.key)}').join(' · ');
}

class ClientBalance {
  final int clientId;
  final num totalBilled;
  final num totalPaid;
  final num outstanding;
  final num advanceAmount;
  final String? lastPaymentDate;
  final String? lastEntryDate;
  final String? oldestUnpaidDate;
  final int entryCount;

  const ClientBalance({
    required this.clientId,
    required this.totalBilled,
    required this.totalPaid,
    required this.outstanding,
    required this.advanceAmount,
    required this.entryCount,
    this.lastPaymentDate,
    this.lastEntryDate,
    this.oldestUnpaidDate,
  });

  static const empty = ClientBalance(
    clientId: 0,
    totalBilled: 0,
    totalPaid: 0,
    outstanding: 0,
    advanceAmount: 0,
    entryCount: 0,
  );

  factory ClientBalance.fromJson(Map<String, dynamic> json) => ClientBalance(
        clientId: parseId(json['client_id']) ?? 0,
        totalBilled: parseNum(json['total_billed']) ?? 0,
        totalPaid: parseNum(json['total_paid']) ?? 0,
        outstanding: parseNum(json['outstanding']) ?? 0,
        advanceAmount: parseNum(json['advance_amount']) ?? 0,
        entryCount: parseId(json['entry_count']) ?? 0,
        lastPaymentDate: json['last_payment_date'] as String?,
        lastEntryDate: json['last_entry_date'] as String?,
        oldestUnpaidDate: json['oldest_unpaid_date'] as String?,
      );
}

const List<String> kPartyKinds = ['COMPANY', 'INDIVIDUAL'];

String partyKindLabel(String value) => value == 'INDIVIDUAL' ? 'Individual' : 'Company';

class ClientEntityRef {
  final int id;
  final String name;
  final String entityKind;
  final String? phone;

  const ClientEntityRef({
    required this.id,
    required this.name,
    required this.entityKind,
    this.phone,
  });

  factory ClientEntityRef.fromJson(Map<String, dynamic> json) => ClientEntityRef(
        id: parseId(json['id'])!,
        name: json['name'] as String? ?? '',
        entityKind: json['entity_kind'] as String? ?? '',
        phone: json['phone'] as String?,
      );
}

/// The receiving-account embed on a client — a narrower shape than the full
/// BankAccount record, with the holder's name resolved inline.
class ClientBankAccountRef {
  final int id;
  final String bankName;
  final String accountNumber;
  final String accountType;
  final String? nickname;
  final String? holderName;

  const ClientBankAccountRef({
    required this.id,
    required this.bankName,
    required this.accountNumber,
    required this.accountType,
    this.nickname,
    this.holderName,
  });

  /// "Axis Bank ••81 — Deekshith (Savings)". Derived, never stored.
  String get displayLabel {
    final last4 = accountNumber.length >= 4
        ? accountNumber.substring(accountNumber.length - 4)
        : accountNumber;
    final head = (nickname != null && nickname!.trim().isNotEmpty)
        ? nickname!.trim()
        : '$bankName ••$last4';
    final typeLabel = accountTypeLabel(accountType);
    return holderName != null ? '$head — $holderName ($typeLabel)' : '$head ($typeLabel)';
  }

  factory ClientBankAccountRef.fromJson(Map<String, dynamic> json) => ClientBankAccountRef(
        id: parseId(json['id'])!,
        bankName: json['bank_name'] as String? ?? '',
        accountNumber: json['account_number'] as String? ?? '',
        accountType: json['account_type'] as String? ?? 'SAVINGS',
        nickname: json['nickname'] as String?,
        holderName: (json['entities'] as Map<String, dynamic>?)?['name'] as String?,
      );
}

class Client {
  final int id;
  final String name;
  final String clientType;
  final String? location;
  final String? address;
  final String? gstNumber;
  final String? notes;
  final bool isActive;
  final String partyKind;
  final int? entityId;
  final ClientEntityRef? entity;
  final int? receivingAccountId;
  final ClientBankAccountRef? bankAccount;
  final ClientBalance balance;
  final Map<String, int> deploymentMix;

  const Client({
    required this.id,
    required this.name,
    required this.clientType,
    required this.isActive,
    required this.balance,
    required this.deploymentMix,
    this.partyKind = 'COMPANY',
    this.entityId,
    this.entity,
    this.receivingAccountId,
    this.bankAccount,
    this.location,
    this.address,
    this.gstNumber,
    this.notes,
  });

  bool get isIndividual => partyKind == 'INDIVIDUAL';

  factory Client.fromJson(Map<String, dynamic> json) => Client(
        id: parseId(json['id'])!,
        name: json['name'] as String? ?? '',
        clientType: json['client_type'] as String? ?? 'VENDOR',
        location: json['location'] as String?,
        address: json['address'] as String?,
        gstNumber: json['gst_number'] as String?,
        notes: json['notes'] as String?,
        isActive: json['is_active'] as bool? ?? true,
        partyKind: json['party_kind'] as String? ?? 'COMPANY',
        entityId: parseId(json['entity_id']),
        entity: json['entities'] != null
            ? ClientEntityRef.fromJson(json['entities'] as Map<String, dynamic>)
            : null,
        receivingAccountId: parseId(json['receiving_account_id']),
        bankAccount: json['bank_accounts'] != null
            ? ClientBankAccountRef.fromJson(json['bank_accounts'] as Map<String, dynamic>)
            : null,
        balance: json['balance'] != null
            ? ClientBalance.fromJson(json['balance'] as Map<String, dynamic>)
            : ClientBalance.empty,
        deploymentMix: (json['deployment_mix'] as Map<String, dynamic>? ?? {})
            .map((k, v) => MapEntry(k, parseIdOr0(v))),
      );
}

class ClientSummary {
  final int totalClients;
  final int activeClients;
  final num totalOutstanding;
  final num totalAdvance;
  final int clientsWithDues;

  const ClientSummary({
    required this.totalClients,
    required this.activeClients,
    required this.totalOutstanding,
    required this.totalAdvance,
    required this.clientsWithDues,
  });

  factory ClientSummary.fromJson(Map<String, dynamic> json) => ClientSummary(
        totalClients: parseId(json['totalClients']) ?? 0,
        activeClients: parseId(json['activeClients']) ?? 0,
        totalOutstanding: parseNum(json['totalOutstanding']) ?? 0,
        totalAdvance: parseNum(json['totalAdvance']) ?? 0,
        clientsWithDues: parseId(json['clientsWithDues']) ?? 0,
      );
}

class LedgerEntry {
  final int id;
  final int clientId;
  final String entryType;
  final String direction;
  final num amount;
  final String entryDate;
  final String? invoiceNo;
  final String? periodMonth;
  final String? paymentMethod;
  final String? reference;
  final String? description;
  final int? reversesEntryId;
  final num runningBalance;
  final bool isReversed;
  final bool isReversal;
  final int attachmentCount;

  const LedgerEntry({
    required this.id,
    required this.clientId,
    required this.entryType,
    required this.direction,
    required this.amount,
    required this.entryDate,
    required this.runningBalance,
    required this.isReversed,
    required this.isReversal,
    this.attachmentCount = 0,
    this.invoiceNo,
    this.periodMonth,
    this.paymentMethod,
    this.reference,
    this.description,
    this.reversesEntryId,
  });

  bool get canReverse => !isReversed && !isReversal;

  factory LedgerEntry.fromJson(Map<String, dynamic> json) => LedgerEntry(
        id: parseId(json['id'])!,
        clientId: parseId(json['client_id'])!,
        entryType: json['entry_type'] as String? ?? 'BILL',
        direction: json['direction'] as String? ?? 'DEBIT',
        amount: parseNum(json['amount']) ?? 0,
        entryDate: json['entry_date'] as String? ?? '',
        invoiceNo: json['invoice_no'] as String?,
        periodMonth: json['period_month'] as String?,
        paymentMethod: json['payment_method'] as String?,
        reference: json['reference'] as String?,
        description: json['description'] as String?,
        reversesEntryId: parseId(json['reverses_entry_id']),
        runningBalance: parseNum(json['running_balance']) ?? 0,
        isReversed: json['is_reversed'] as bool? ?? false,
        isReversal: json['is_reversal'] as bool? ?? false,
        attachmentCount: parseId(json['attachment_count']) ?? 0,
      );
}

class ClientContact {
  final int id;
  final int clientId;
  final String name;
  final String? role;
  final String? designation;
  final String? phone;
  final String? altPhone;
  final String? email;
  final bool isPrimary;

  const ClientContact({
    required this.id,
    required this.clientId,
    required this.name,
    required this.isPrimary,
    this.role,
    this.designation,
    this.phone,
    this.altPhone,
    this.email,
  });

  factory ClientContact.fromJson(Map<String, dynamic> json) => ClientContact(
        id: parseId(json['id'])!,
        clientId: parseId(json['client_id'])!,
        name: json['name'] as String? ?? '',
        role: json['role'] as String?,
        designation: json['designation'] as String?,
        phone: json['phone'] as String?,
        altPhone: json['alt_phone'] as String?,
        email: json['email'] as String?,
        isPrimary: json['is_primary'] as bool? ?? false,
      );
}

class DeploymentVehicleRef {
  final int id;
  final String vehicleNumber;
  final String? company;
  final String? model;

  const DeploymentVehicleRef({required this.id, required this.vehicleNumber, this.company, this.model});

  factory DeploymentVehicleRef.fromJson(Map<String, dynamic> json) => DeploymentVehicleRef(
        id: parseId(json['id'])!,
        vehicleNumber: json['vehicle_number'] as String? ?? '',
        company: json['company'] as String?,
        model: json['model'] as String?,
      );
}

/// A vehicle running for a client — either linked to a real fleet vehicle
/// ([vehicleId] set, [quantity] always 1) or a declared bucket describing
/// units not tracked individually ([vehicleId] null, [quantity] >= 1).
class ClientDeployment {
  final int id;
  final int clientId;
  final int? vehicleId;
  final int quantity;
  final String vehicleType;
  final int? seatingCapacity;
  final String? truckType;
  final String? containerLength;
  final String? axleType;
  final String? containerBodyType;
  final num? monthlyRate;
  final String? startDate;
  final String? endDate;
  final bool isActive;
  final DeploymentVehicleRef? vehicle;

  const ClientDeployment({
    required this.id,
    required this.clientId,
    required this.quantity,
    required this.vehicleType,
    required this.isActive,
    this.vehicleId,
    this.seatingCapacity,
    this.truckType,
    this.containerLength,
    this.axleType,
    this.containerBodyType,
    this.monthlyRate,
    this.startDate,
    this.endDate,
    this.vehicle,
  });

  factory ClientDeployment.fromJson(Map<String, dynamic> json) => ClientDeployment(
        id: parseId(json['id'])!,
        clientId: parseId(json['client_id'])!,
        vehicleId: parseId(json['vehicle_id']),
        quantity: parseId(json['quantity']) ?? 1,
        vehicleType: json['vehicle_type'] as String? ?? 'CAR',
        seatingCapacity: parseId(json['seating_capacity']),
        truckType: json['truck_type'] as String?,
        containerLength: json['container_length'] as String?,
        axleType: json['axle_type'] as String?,
        containerBodyType: json['container_body_type'] as String?,
        monthlyRate: parseNum(json['monthly_rate']),
        startDate: json['start_date'] as String?,
        endDate: json['end_date'] as String?,
        isActive: json['is_active'] as bool? ?? true,
        vehicle: json['vehicles'] != null
            ? DeploymentVehicleRef.fromJson(json['vehicles'] as Map<String, dynamic>)
            : null,
      );
}

/// `GET /api/clients/[id]` payload.
class ClientDetail {
  final Client client;
  final ClientBalance balance;
  final List<ClientContact> contacts;
  final List<ClientDeployment> deployments;
  final Map<String, int> fleetMix;

  const ClientDetail({
    required this.client,
    required this.balance,
    required this.contacts,
    required this.deployments,
    required this.fleetMix,
  });

  factory ClientDetail.fromJson(Map<String, dynamic> json) => ClientDetail(
        client: Client.fromJson(json['client'] as Map<String, dynamic>),
        balance: json['balance'] != null
            ? ClientBalance.fromJson(json['balance'] as Map<String, dynamic>)
            : ClientBalance.empty,
        contacts: (json['contacts'] as List<dynamic>? ?? [])
            .map((e) => ClientContact.fromJson(e as Map<String, dynamic>))
            .toList(),
        deployments: (json['deployments'] as List<dynamic>? ?? [])
            .map((e) => ClientDeployment.fromJson(e as Map<String, dynamic>))
            .toList(),
        fleetMix: (json['fleet_mix'] as Map<String, dynamic>? ?? {})
            .map((k, v) => MapEntry(k, parseIdOr0(v))),
      );
}

class ClientFilters implements ListFilters {
  final String? clientType;
  final bool hasDues;
  final String? partyKind;

  const ClientFilters({this.clientType, this.hasDues = false, this.partyKind});

  static const none = ClientFilters();

  @override
  bool get isActive => clientType != null || hasDues || partyKind != null;

  ClientFilters copyWith({
    String? clientType,
    bool clearType = false,
    bool? hasDues,
    String? partyKind,
    bool clearPartyKind = false,
  }) {
    return ClientFilters(
      clientType: clearType ? null : (clientType ?? this.clientType),
      hasDues: hasDues ?? this.hasDues,
      partyKind: clearPartyKind ? null : (partyKind ?? this.partyKind),
    );
  }
}
