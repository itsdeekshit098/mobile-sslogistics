import '../utils/json_parse.dart';

const List<String> kAccountTypes = ['SAVINGS', 'CURRENT', 'OD', 'CC'];
const List<String> kMandateTypes = ['NACH', 'ECS', 'SI', 'PDC', 'MANUAL'];

String accountTypeLabel(String value) {
  switch (value) {
    case 'SAVINGS':
      return 'Savings';
    case 'CURRENT':
      return 'Current';
    case 'OD':
      return 'Overdraft (OD)';
    case 'CC':
      return 'Cash Credit (CC)';
    default:
      return value;
  }
}

String mandateTypeLabel(String? value) {
  switch (value) {
    case 'NACH':
      return 'NACH';
    case 'ECS':
      return 'ECS';
    case 'SI':
      return 'Standing Instruction';
    case 'PDC':
      return 'Post-Dated Cheques';
    case 'MANUAL':
      return 'Manual';
    default:
      return value ?? '';
  }
}

/// One of our own bank accounts — `bank_accounts` table
/// (sql/34_add_bank_accounts.sql). Recorded so a loan can say which account
/// its EMI mandate debits from. Not a lender, and deliberately never
/// referenced from any payment row — see that migration's header for why a
/// per-account balance can't be derived here.
class BankAccount {
  final int id;
  final int holderEntityId;
  final String? holderName;
  final String bankName;
  final String accountNumber;
  final String accountType;
  final String? ifsc;
  final String? branch;
  final String? nickname;
  final String? notes;
  final bool isActive;
  final int? loanCount;

  const BankAccount({
    required this.id,
    required this.holderEntityId,
    required this.bankName,
    required this.accountNumber,
    required this.accountType,
    required this.isActive,
    this.holderName,
    this.ifsc,
    this.branch,
    this.nickname,
    this.notes,
    this.loanCount,
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

  factory BankAccount.fromJson(Map<String, dynamic> json) => BankAccount(
        id: parseId(json['id'])!,
        holderEntityId: parseId(json['holder_entity_id']) ?? 0,
        holderName: (json['entities'] as Map<String, dynamic>?)?['name'] as String?,
        bankName: json['bank_name'] as String? ?? '',
        accountNumber: json['account_number'] as String? ?? '',
        accountType: json['account_type'] as String? ?? 'SAVINGS',
        ifsc: json['ifsc'] as String?,
        branch: json['branch'] as String?,
        nickname: json['nickname'] as String?,
        notes: json['notes'] as String?,
        isActive: json['is_active'] as bool? ?? true,
        loanCount: parseId(json['loan_count']),
      );

  @override
  bool operator ==(Object other) => other is BankAccount && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
