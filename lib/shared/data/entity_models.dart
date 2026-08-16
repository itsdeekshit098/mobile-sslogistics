/// A firm or a person — `entities` table. Backs the borrower/owner pickers
/// across loans, fundings and vehicles, and the full "Firms & Owners" CRUD
/// screen (`features/owners`).
///
/// `entities` absorbed the old `vehicle_owners` table on the web side —
/// `owner_name`/`owner_type` survive on vehicle rows as trigger-maintained
/// mirrors so `/api/vehicle-owners` and the vehicles feature's own picker
/// keep working unchanged. This model is the richer one used where the full
/// record is wanted.
library;

import '../utils/json_parse.dart';

const List<String> kEntityKinds = ['FIRM', 'PERSON'];
const List<String> kEntityRelationships = ['INTERNAL', 'EXTERNAL'];

String entityKindLabel(String value) => value == 'PERSON' ? 'Person' : 'Firm';
String entityRelationshipLabel(String value) => value == 'EXTERNAL' ? 'External' : 'Ours';

class Entity {
  final int id;
  final String name;
  final String entityKind; // 'FIRM' | 'PERSON'
  final String relationship; // 'INTERNAL' | 'EXTERNAL'
  final int? proprietorEntityId;
  final String? proprietorName;
  final String? phone;
  final String? email;
  final String? pan;
  final String? gstNumber;
  final String? address;
  final String? notes;
  final bool isActive;
  final int? vehicleCount;

  const Entity({
    required this.id,
    required this.name,
    required this.entityKind,
    required this.relationship,
    required this.isActive,
    this.proprietorEntityId,
    this.proprietorName,
    this.phone,
    this.email,
    this.pan,
    this.gstNumber,
    this.address,
    this.notes,
    this.vehicleCount,
  });

  factory Entity.fromJson(Map<String, dynamic> json) => Entity(
        id: parseId(json['id'])!,
        name: json['name'] as String? ?? '',
        entityKind: json['entity_kind'] as String? ?? 'FIRM',
        relationship: json['relationship'] as String? ?? 'INTERNAL',
        proprietorEntityId: parseId(json['proprietor_entity_id']),
        proprietorName: json['proprietor_name'] as String?,
        phone: json['phone'] as String?,
        email: json['email'] as String?,
        pan: json['pan'] as String?,
        gstNumber: json['gst_number'] as String?,
        address: json['address'] as String?,
        notes: json['notes'] as String?,
        isActive: json['is_active'] as bool? ?? true,
        vehicleCount: parseId(json['vehicle_count']),
      );

  @override
  bool operator ==(Object other) => other is Entity && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
