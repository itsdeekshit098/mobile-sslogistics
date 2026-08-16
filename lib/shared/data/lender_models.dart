/// A lender — `lenders` table. Shared between institutional loans
/// (`lender_kind: 'INSTITUTION'`) and private fundings
/// (`lender_kind: 'PRIVATE'`), so the same person used both ways isn't
/// duplicated across two lists.
library;

import '../utils/json_parse.dart';

class Lender {
  final int id;
  final String name;
  final String lenderKind;
  final String? phone;
  final String? contactPerson;
  final bool isActive;

  const Lender({
    required this.id,
    required this.name,
    required this.lenderKind,
    required this.isActive,
    this.phone,
    this.contactPerson,
  });

  factory Lender.fromJson(Map<String, dynamic> json) => Lender(
        id: parseId(json['id'])!,
        name: json['name'] as String? ?? '',
        lenderKind: json['lender_kind'] as String? ?? 'INSTITUTION',
        phone: json['phone'] as String?,
        contactPerson: json['contact_person'] as String?,
        isActive: json['is_active'] as bool? ?? true,
      );

  @override
  bool operator ==(Object other) => other is Lender && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
