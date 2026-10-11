import '../../../shared/data/bank_account_models.dart' show accountTypeLabel;
import '../../../shared/state/list_filters.dart';
import '../../../shared/utils/json_parse.dart';

// ── Fixed enumerations (Postgres CHECK constraints, not lookup_options) ────

const List<String> kLoanStatuses = ['ACTIVE', 'CLOSED', 'FORECLOSED', 'DEFAULTED'];
const List<String> kInstallmentStatuses = [
  'PENDING',
  'PARTIAL',
  'OVERDUE',
  'PAID',
  'BOUNCED',
  'WAIVED',
];
const List<String> kPaymentTypes = [
  'EMI',
  'PREPAYMENT',
  'FORECLOSURE',
  'CHARGE',
  'ADJUSTMENT',
];

String loanStatusLabel(String status) {
  switch (status) {
    case 'ACTIVE':
      return 'Active';
    case 'CLOSED':
      return 'Closed';
    case 'FORECLOSED':
      return 'Foreclosed';
    case 'DEFAULTED':
      return 'Defaulted';
    default:
      return status;
  }
}

String installmentStatusLabel(String status) {
  switch (status) {
    case 'PENDING':
      return 'Pending';
    case 'PARTIAL':
      return 'Partly paid';
    case 'OVERDUE':
      return 'Overdue';
    case 'PAID':
      return 'Paid';
    case 'BOUNCED':
      return 'Bounced';
    case 'WAIVED':
      return 'Waived';
    default:
      return status;
  }
}

/// Implied flat annual rate from the schedule alone — EMI × tenure vs
/// principal — not the reducing-balance rate a lender actually applies.
/// Display-only, for cross-checking the stored interestRate; never fed back
/// into the schedule or a stored column. Mirrors the web app's
/// `flatRoiFromSchedule` (loansPage.utils.ts) exactly, including returning
/// null (rather than a negative/NaN rate) whenever the schedule's total
/// payable doesn't exceed the principal.
num? flatRoiFromSchedule(num principal, num totalPayable, int totalInstallments) {
  if (principal <= 0 || totalInstallments <= 0) return null;
  final totalInterest = totalPayable - principal;
  if (totalInterest < 0) return null;
  final tenureYears = totalInstallments / 12;
  return (totalInterest / principal / tenureYears) * 100;
}

String paymentTypeLabel(String type) {
  switch (type) {
    case 'EMI':
      return 'EMI';
    case 'PREPAYMENT':
      return 'Prepayment';
    case 'FORECLOSURE':
      return 'Foreclosure';
    case 'CHARGE':
      return 'Charge';
    case 'ADJUSTMENT':
      return 'Adjustment';
    default:
      return type;
  }
}

// ── Embedded reference rows ─────────────────────────────────────────────────

class LoanEntityRef {
  final int id;
  final String name;
  final String entityKind;
  final String relationship;

  const LoanEntityRef({
    required this.id,
    required this.name,
    required this.entityKind,
    required this.relationship,
  });

  factory LoanEntityRef.fromJson(Map<String, dynamic> json) => LoanEntityRef(
        id: parseId(json['id'])!,
        name: json['name'] as String? ?? '',
        entityKind: json['entity_kind'] as String? ?? '',
        relationship: json['relationship'] as String? ?? '',
      );
}

class LoanLenderRef {
  final int id;
  final String name;
  final String lenderKind;

  const LoanLenderRef({required this.id, required this.name, required this.lenderKind});

  factory LoanLenderRef.fromJson(Map<String, dynamic> json) => LoanLenderRef(
        id: parseId(json['id'])!,
        name: json['name'] as String? ?? '',
        lenderKind: json['lender_kind'] as String? ?? '',
      );
}

class LoanBankAccountRef {
  final int id;
  final String bankName;
  final String accountNumber;
  final String accountType;
  final String? nickname;
  final String? holderName;

  const LoanBankAccountRef({
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

  factory LoanBankAccountRef.fromJson(Map<String, dynamic> json) => LoanBankAccountRef(
        id: parseId(json['id'])!,
        bankName: json['bank_name'] as String? ?? '',
        accountNumber: json['account_number'] as String? ?? '',
        accountType: json['account_type'] as String? ?? 'SAVINGS',
        nickname: json['nickname'] as String?,
        holderName: (json['entities'] as Map<String, dynamic>?)?['name'] as String?,
      );
}

class LoanVehicleRef {
  final int id;
  final String vehicleNumber;
  final String? vehicleType;
  final String? company;
  final String? model;

  const LoanVehicleRef({
    required this.id,
    required this.vehicleNumber,
    this.vehicleType,
    this.company,
    this.model,
  });

  factory LoanVehicleRef.fromJson(Map<String, dynamic> json) => LoanVehicleRef(
        id: parseId(json['id'])!,
        vehicleNumber: json['vehicle_number'] as String? ?? '',
        vehicleType: json['vehicle_type'] as String?,
        company: json['company'] as String?,
        model: json['model'] as String?,
      );
}

// ── Loan balance (derived, never computed on-device) ────────────────────────

class LoanBalance {
  final int loanId;
  final num totalPayable;
  final num totalPaid;
  final num totalCharges;
  final num outstanding;
  final int installmentsPaid;
  final int installmentsLeft;
  final String? nextDueDate;
  final num? nextDueAmount;
  final int overdueCount;
  final num overdueAmount;
  final String? finalDueDate;
  final String? lastPaymentDate;

  const LoanBalance({
    required this.loanId,
    required this.totalPayable,
    required this.totalPaid,
    required this.totalCharges,
    required this.outstanding,
    required this.installmentsPaid,
    required this.installmentsLeft,
    required this.overdueCount,
    required this.overdueAmount,
    this.nextDueDate,
    this.nextDueAmount,
    this.finalDueDate,
    this.lastPaymentDate,
  });

  static const empty = LoanBalance(
    loanId: 0,
    totalPayable: 0,
    totalPaid: 0,
    totalCharges: 0,
    outstanding: 0,
    installmentsPaid: 0,
    installmentsLeft: 0,
    overdueCount: 0,
    overdueAmount: 0,
  );

  factory LoanBalance.fromJson(Map<String, dynamic> json) => LoanBalance(
        loanId: parseId(json['loan_id']) ?? 0,
        totalPayable: parseNum(json['total_payable']) ?? 0,
        totalPaid: parseNum(json['total_paid']) ?? 0,
        totalCharges: parseNum(json['total_charges']) ?? 0,
        outstanding: parseNum(json['outstanding']) ?? 0,
        installmentsPaid: parseId(json['installments_paid']) ?? 0,
        installmentsLeft: parseId(json['installments_left']) ?? 0,
        nextDueDate: json['next_due_date'] as String?,
        nextDueAmount: parseNum(json['next_due_amount']),
        overdueCount: parseId(json['overdue_count']) ?? 0,
        overdueAmount: parseNum(json['overdue_amount']) ?? 0,
        finalDueDate: json['final_due_date'] as String?,
        lastPaymentDate: json['last_payment_date'] as String?,
      );

  double get progress {
    final total = installmentsPaid + installmentsLeft;
    if (total <= 0) return 0;
    return installmentsPaid / total;
  }
}

// ── Loan ─────────────────────────────────────────────────────────────────

class Loan {
  final int id;
  final String loanType;
  final int borrowerEntityId;
  final int? lenderId;
  final String? loanNumber;
  final int? vehicleId;
  final String? collateralDescription;
  final num principalAmount;
  final num? disbursedAmount;
  final num? interestRate;
  final num? processingFee;
  final String startDate;
  final String firstEmiDate;
  final num emiAmount;
  final int emiDayOfMonth;
  final int totalInstallments;
  final num? outstandingOverride;
  final int? debitAccountId;
  final String? mandateType;
  final String status;
  final String? closedOn;
  final String? notes;
  final LoanEntityRef? borrower;
  final LoanLenderRef? lender;
  final LoanVehicleRef? vehicle;
  final LoanBankAccountRef? bankAccount;
  final LoanBalance balance;

  const Loan({
    required this.id,
    required this.loanType,
    required this.borrowerEntityId,
    required this.principalAmount,
    required this.startDate,
    required this.firstEmiDate,
    required this.emiAmount,
    required this.emiDayOfMonth,
    required this.totalInstallments,
    required this.status,
    required this.balance,
    this.lenderId,
    this.loanNumber,
    this.vehicleId,
    this.collateralDescription,
    this.disbursedAmount,
    this.interestRate,
    this.processingFee,
    this.outstandingOverride,
    this.debitAccountId,
    this.mandateType,
    this.closedOn,
    this.notes,
    this.borrower,
    this.lender,
    this.vehicle,
    this.bankAccount,
  });

  /// What a card shows for "who/where this loan is on" — collateral first
  /// (a vehicle registration reads better than "VEHICLE"), else the loan
  /// number quoted with the lender.
  String get subtitle {
    if (vehicle != null) return vehicle!.vehicleNumber;
    if (collateralDescription != null && collateralDescription!.isNotEmpty) {
      return collateralDescription!;
    }
    return loanNumber ?? '';
  }

  factory Loan.fromJson(Map<String, dynamic> json) => Loan(
        id: parseId(json['id'])!,
        loanType: json['loan_type'] as String? ?? '',
        borrowerEntityId: parseId(json['borrower_entity_id']) ?? 0,
        lenderId: parseId(json['lender_id']),
        loanNumber: json['loan_number'] as String?,
        vehicleId: parseId(json['vehicle_id']),
        collateralDescription: json['collateral_description'] as String?,
        principalAmount: parseNum(json['principal_amount']) ?? 0,
        disbursedAmount: parseNum(json['disbursed_amount']),
        interestRate: parseNum(json['interest_rate']),
        processingFee: parseNum(json['processing_fee']),
        startDate: json['start_date'] as String? ?? '',
        firstEmiDate: json['first_emi_date'] as String? ?? '',
        emiAmount: parseNum(json['emi_amount']) ?? 0,
        emiDayOfMonth: parseId(json['emi_day_of_month']) ?? 1,
        totalInstallments: parseId(json['total_installments']) ?? 0,
        outstandingOverride: parseNum(json['outstanding_override']),
        debitAccountId: parseId(json['debit_account_id']),
        mandateType: json['mandate_type'] as String?,
        status: json['status'] as String? ?? 'ACTIVE',
        closedOn: json['closed_on'] as String?,
        notes: json['notes'] as String?,
        borrower: json['entities'] != null
            ? LoanEntityRef.fromJson(json['entities'] as Map<String, dynamic>)
            : null,
        lender: json['lenders'] != null
            ? LoanLenderRef.fromJson(json['lenders'] as Map<String, dynamic>)
            : null,
        vehicle: json['vehicles'] != null
            ? LoanVehicleRef.fromJson(json['vehicles'] as Map<String, dynamic>)
            : null,
        bankAccount: json['bank_accounts'] != null
            ? LoanBankAccountRef.fromJson(json['bank_accounts'] as Map<String, dynamic>)
            : null,
        balance: json['balance'] != null
            ? LoanBalance.fromJson(json['balance'] as Map<String, dynamic>)
            : LoanBalance.empty,
      );
}

// ── Installment (with derived status from loan_installment_state) ──────────

class LoanInstallment {
  final int id;
  final int loanId;
  final int installmentNo;
  final String dueDate;
  final num amountDue;
  final String? manualStatus;
  final String? notes;
  final num amountPaid;
  final num amountRemaining;
  final String status;

  const LoanInstallment({
    required this.id,
    required this.loanId,
    required this.installmentNo,
    required this.dueDate,
    required this.amountDue,
    required this.amountPaid,
    required this.amountRemaining,
    required this.status,
    this.manualStatus,
    this.notes,
  });

  bool get isSettled => status == 'PAID' || status == 'WAIVED';

  factory LoanInstallment.fromJson(Map<String, dynamic> json) => LoanInstallment(
        id: parseId(json['id'])!,
        loanId: parseId(json['loan_id'])!,
        installmentNo: parseId(json['installment_no'])!,
        dueDate: json['due_date'] as String,
        amountDue: parseNum(json['amount_due']) ?? 0,
        amountPaid: parseNum(json['amount_paid']) ?? 0,
        amountRemaining: parseNum(json['amount_remaining']) ?? 0,
        status: json['status'] as String? ?? 'PENDING',
        manualStatus: json['manual_status'] as String?,
        notes: json['notes'] as String?,
      );
}

// ── Payment (append-only, reversal-aware) ───────────────────────────────────

class LoanPayment {
  final int id;
  final int loanId;
  final int? installmentId;
  final String paymentType;
  final num amount;
  final String paidOn;
  final String? paymentMethod;
  final String? reference;
  final String? notes;
  final int? reversesPaymentId;
  final bool isReversed;
  final bool isReversal;

  const LoanPayment({
    required this.id,
    required this.loanId,
    required this.paymentType,
    required this.amount,
    required this.paidOn,
    required this.isReversed,
    required this.isReversal,
    this.installmentId,
    this.paymentMethod,
    this.reference,
    this.notes,
    this.reversesPaymentId,
  });

  /// A row that has already been undone, or is itself a reversal, can't be
  /// reversed again.
  bool get canReverse => !isReversed && !isReversal;

  factory LoanPayment.fromJson(Map<String, dynamic> json) => LoanPayment(
        id: parseId(json['id'])!,
        loanId: parseId(json['loan_id'])!,
        installmentId: parseId(json['installment_id']),
        paymentType: json['payment_type'] as String? ?? 'EMI',
        amount: parseNum(json['amount']) ?? 0,
        paidOn: json['paid_on'] as String? ?? '',
        paymentMethod: json['payment_method'] as String?,
        reference: json['reference'] as String?,
        notes: json['notes'] as String?,
        reversesPaymentId: parseId(json['reverses_payment_id']),
        isReversed: json['is_reversed'] as bool? ?? false,
        isReversal: json['is_reversal'] as bool? ?? false,
      );
}

/// The `GET /api/loans/[id]` payload: terms, balance, full schedule, full log.
class LoanDetail {
  final Loan loan;
  final LoanBalance balance;
  final List<LoanInstallment> installments;
  final List<LoanPayment> payments;

  const LoanDetail({
    required this.loan,
    required this.balance,
    required this.installments,
    required this.payments,
  });

  factory LoanDetail.fromJson(Map<String, dynamic> json) => LoanDetail(
        loan: Loan.fromJson(json['loan'] as Map<String, dynamic>),
        balance: json['balance'] != null
            ? LoanBalance.fromJson(json['balance'] as Map<String, dynamic>)
            : LoanBalance.empty,
        installments: (json['installments'] as List<dynamic>? ?? [])
            .map((e) => LoanInstallment.fromJson(e as Map<String, dynamic>))
            .toList(),
        payments: (json['payments'] as List<dynamic>? ?? [])
            .map((e) => LoanPayment.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

// ── Portfolio summary (list screen stat strip) ──────────────────────────────

class LoanSummary {
  final num totalOutstanding;
  final num totalMonthlyEmi;
  final int dueThisMonth;
  final int overdueCount;
  final num overdueAmount;
  final int activeLoans;
  final int openFundings;
  final num fundingPrincipalOutstanding;

  const LoanSummary({
    required this.totalOutstanding,
    required this.totalMonthlyEmi,
    required this.dueThisMonth,
    required this.overdueCount,
    required this.overdueAmount,
    required this.activeLoans,
    required this.openFundings,
    required this.fundingPrincipalOutstanding,
  });

  factory LoanSummary.fromJson(Map<String, dynamic> json) => LoanSummary(
        totalOutstanding: parseNum(json['totalOutstanding']) ?? 0,
        totalMonthlyEmi: parseNum(json['totalMonthlyEmi']) ?? 0,
        dueThisMonth: parseId(json['dueThisMonth']) ?? 0,
        overdueCount: parseId(json['overdueCount']) ?? 0,
        overdueAmount: parseNum(json['overdueAmount']) ?? 0,
        activeLoans: parseId(json['activeLoans']) ?? 0,
        openFundings: parseId(json['openFundings']) ?? 0,
        fundingPrincipalOutstanding: parseNum(json['fundingPrincipalOutstanding']) ?? 0,
      );
}

// ── List filters ─────────────────────────────────────────────────────────

class LoanFilters implements ListFilters {
  final String? status;
  final String? loanType;
  final int? borrowerEntityId;
  final int? lenderId;
  final bool overdueOnly;

  const LoanFilters({
    this.status,
    this.loanType,
    this.borrowerEntityId,
    this.lenderId,
    this.overdueOnly = false,
  });

  static const none = LoanFilters();

  @override
  bool get isActive =>
      status != null ||
      loanType != null ||
      borrowerEntityId != null ||
      lenderId != null ||
      overdueOnly;

  LoanFilters copyWith({
    String? status,
    bool clearStatus = false,
    String? loanType,
    bool clearLoanType = false,
    int? borrowerEntityId,
    bool clearBorrower = false,
    int? lenderId,
    bool clearLender = false,
    bool? overdueOnly,
  }) {
    return LoanFilters(
      status: clearStatus ? null : (status ?? this.status),
      loanType: clearLoanType ? null : (loanType ?? this.loanType),
      borrowerEntityId: clearBorrower ? null : (borrowerEntityId ?? this.borrowerEntityId),
      lenderId: clearLender ? null : (lenderId ?? this.lenderId),
      overdueOnly: overdueOnly ?? this.overdueOnly,
    );
  }
}

// ── Create/update payload ───────────────────────────────────────────────

class LoanDto {
  final String loanType;
  final int borrowerEntityId;
  final int? lenderId;
  final String? loanNumber;
  final int? vehicleId;
  final String? collateralDescription;
  final num principalAmount;
  final num? disbursedAmount;
  final num? interestRate;
  final num? processingFee;
  final String startDate;
  final String firstEmiDate;
  final num emiAmount;
  final int emiDayOfMonth;
  final int totalInstallments;
  final num? outstandingOverride;
  final int? debitAccountId;
  final String? mandateType;
  final String? notes;

  const LoanDto({
    required this.loanType,
    required this.borrowerEntityId,
    required this.principalAmount,
    required this.startDate,
    required this.firstEmiDate,
    required this.emiAmount,
    required this.emiDayOfMonth,
    required this.totalInstallments,
    this.lenderId,
    this.loanNumber,
    this.vehicleId,
    this.collateralDescription,
    this.disbursedAmount,
    this.interestRate,
    this.processingFee,
    this.outstandingOverride,
    this.debitAccountId,
    this.mandateType,
    this.notes,
  });

  Map<String, dynamic> toJson() => {
        'loan_type': loanType,
        'borrower_entity_id': borrowerEntityId,
        'lender_id': lenderId,
        'loan_number': loanNumber,
        'vehicle_id': vehicleId,
        'collateral_description': collateralDescription,
        'principal_amount': principalAmount,
        'disbursed_amount': disbursedAmount,
        'interest_rate': interestRate,
        'processing_fee': processingFee,
        'start_date': startDate,
        'first_emi_date': firstEmiDate,
        'emi_amount': emiAmount,
        'emi_day_of_month': emiDayOfMonth,
        'total_installments': totalInstallments,
        'outstanding_override': outstandingOverride,
        'debit_account_id': debitAccountId,
        'mandate_type': mandateType,
        'notes': notes,
      };
}

// ── EMI calendar ("Due Soon") ────────────────────────────────────────────

/// One installment as shown in the calendar — carries its own loan context
/// since the calendar spans every loan at once.
class CalendarInstallment {
  final int id;
  final int loanId;
  final int installmentNo;
  final String dueDate;
  final num amountDue;
  final num amountRemaining;
  final String status;
  final Loan? loan;

  const CalendarInstallment({
    required this.id,
    required this.loanId,
    required this.installmentNo,
    required this.dueDate,
    required this.amountDue,
    required this.amountRemaining,
    required this.status,
    this.loan,
  });

  factory CalendarInstallment.fromJson(Map<String, dynamic> json) => CalendarInstallment(
        id: parseId(json['id'])!,
        loanId: parseId(json['loan_id'])!,
        installmentNo: parseId(json['installment_no']) ?? 0,
        dueDate: json['due_date'] as String,
        amountDue: parseNum(json['amount_due']) ?? 0,
        amountRemaining: parseNum(json['amount_remaining']) ?? 0,
        status: json['status'] as String? ?? 'PENDING',
        loan: json['loan'] != null ? Loan.fromJson(json['loan'] as Map<String, dynamic>) : null,
      );
}

class CalendarDay {
  final String date;
  final bool isOverdue;
  final num total;
  final List<CalendarInstallment> installments;

  const CalendarDay({
    required this.date,
    required this.isOverdue,
    required this.total,
    required this.installments,
  });

  factory CalendarDay.fromJson(Map<String, dynamic> json) => CalendarDay(
        date: json['date'] as String,
        isOverdue: json['is_overdue'] as bool? ?? false,
        total: parseNum(json['total']) ?? 0,
        installments: (json['installments'] as List<dynamic>? ?? [])
            .map((e) => CalendarInstallment.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class LoanCalendar {
  final String from;
  final String to;
  final List<CalendarDay> days;
  final List<CalendarInstallment> overdue;
  final num totalDue;

  const LoanCalendar({
    required this.from,
    required this.to,
    required this.days,
    required this.overdue,
    required this.totalDue,
  });

  factory LoanCalendar.fromJson(Map<String, dynamic> json) => LoanCalendar(
        from: json['from'] as String? ?? '',
        to: json['to'] as String? ?? '',
        days: (json['days'] as List<dynamic>? ?? [])
            .map((e) => CalendarDay.fromJson(e as Map<String, dynamic>))
            .toList(),
        overdue: (json['overdue'] as List<dynamic>? ?? [])
            .map((e) => CalendarInstallment.fromJson(e as Map<String, dynamic>))
            .toList(),
        totalDue: parseNum(json['total_due']) ?? 0,
      );
}
