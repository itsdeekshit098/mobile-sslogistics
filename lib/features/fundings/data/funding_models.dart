import '../../../shared/state/list_filters.dart';
import '../../../shared/utils/json_parse.dart';

const List<String> kInterestModes = ['PERCENT', 'FIXED'];
const List<String> kRoiBases = ['MONTHLY', 'ANNUAL'];
const List<String> kFundingEntryTypes = [
  'PRINCIPAL_TAKEN',
  'PRINCIPAL_REPAID',
  'INTEREST_PAID',
  'ADJUSTMENT',
];
const List<String> kFundingStatuses = ['OPEN', 'SETTLED'];
const List<String> kFundingDirections = ['BORROWED', 'LENT'];

/// Same entry types, borrower voice vs. lender voice — the DB values never
/// change (see sql/35_add_funding_direction.sql), only how they're described.
String fundingEntryTypeLabel(String type, {String direction = 'BORROWED'}) {
  final isLent = direction == 'LENT';
  switch (type) {
    case 'PRINCIPAL_TAKEN':
      return isLent ? 'Lent more' : 'Borrowed more';
    case 'PRINCIPAL_REPAID':
      return isLent ? 'Principal recovered' : 'Repaid principal';
    case 'INTEREST_PAID':
      return isLent ? 'Interest received' : 'Paid interest';
    case 'ADJUSTMENT':
      return 'Adjustment / write-off';
    default:
      return type;
  }
}

/// "Total Owed" for money we owe, "Total Receivable" for money owed to us.
String fundingTotalDueLabel(String direction) =>
    direction == 'LENT' ? 'Total Receivable' : 'Total Owed';

String fundingDirectionLabel(String direction) =>
    direction == 'LENT' ? 'Lent Out' : 'Borrowed';

class FundingLenderRef {
  final int id;
  final String name;
  final String lenderKind;
  final String? phone;

  const FundingLenderRef({
    required this.id,
    required this.name,
    required this.lenderKind,
    this.phone,
  });

  factory FundingLenderRef.fromJson(Map<String, dynamic> json) => FundingLenderRef(
        id: parseId(json['id'])!,
        name: json['name'] as String? ?? '',
        lenderKind: json['lender_kind'] as String? ?? '',
        phone: json['phone'] as String?,
      );
}

class FundingEntityRef {
  final int id;
  final String name;
  final String entityKind;

  const FundingEntityRef({required this.id, required this.name, required this.entityKind});

  factory FundingEntityRef.fromJson(Map<String, dynamic> json) => FundingEntityRef(
        id: parseId(json['id'])!,
        name: json['name'] as String? ?? '',
        entityKind: json['entity_kind'] as String? ?? '',
      );
}

class FundingLoanRef {
  final int id;
  final String loanType;
  final String? loanNumber;

  const FundingLoanRef({required this.id, required this.loanType, this.loanNumber});

  factory FundingLoanRef.fromJson(Map<String, dynamic> json) => FundingLoanRef(
        id: parseId(json['id'])!,
        loanType: json['loan_type'] as String? ?? '',
        loanNumber: json['loan_number'] as String?,
      );
}

/// One agreed rate, in force from [effectiveFrom] until the next rate row
/// (or forever, if it's the latest). Never edited — a renegotiation is a new
/// row, so interest already accrued keeps its original rate.
class FundingRate {
  final int? id;
  final num? roi;
  final String? roiBasis;
  final num? fixedInterestAmount;
  final String effectiveFrom;
  final String? note;

  const FundingRate({
    required this.effectiveFrom,
    this.id,
    this.roi,
    this.roiBasis,
    this.fixedInterestAmount,
    this.note,
  });

  factory FundingRate.fromJson(Map<String, dynamic> json) => FundingRate(
        id: parseId(json['id']),
        roi: parseNum(json['roi']),
        roiBasis: json['roi_basis'] as String?,
        fixedInterestAmount: parseNum(json['fixed_interest_amount']),
        effectiveFrom: json['effective_from'] as String? ?? '',
        note: json['note'] as String?,
      );
}

/// One row of the month-by-month interest table — the thing you'd actually
/// show a funder who asks what he's owed.
class MonthlyBreakdownRow {
  final String month;
  final int days;
  final num averagePrincipal;
  final num? monthlyRate;
  final num interestAccrued;
  final num interestPaid;
  final num interestBalance;

  const MonthlyBreakdownRow({
    required this.month,
    required this.days,
    required this.averagePrincipal,
    required this.interestAccrued,
    required this.interestPaid,
    required this.interestBalance,
    this.monthlyRate,
  });

  factory MonthlyBreakdownRow.fromJson(Map<String, dynamic> json) => MonthlyBreakdownRow(
        month: json['month'] as String,
        days: parseId(json['days']) ?? 0,
        averagePrincipal: parseNum(json['average_principal']) ?? 0,
        monthlyRate: parseNum(json['monthly_rate']),
        interestAccrued: parseNum(json['interest_accrued']) ?? 0,
        interestPaid: parseNum(json['interest_paid']) ?? 0,
        interestBalance: parseNum(json['interest_balance']) ?? 0,
      );
}

/// The full interest position — server-computed, never recalculated on
/// device. Simple, non-compounding interest, pro-rated by days.
class FundingComputation {
  final num principalTaken;
  final num principalRepaid;
  final num principalOutstanding;
  final num interestAccrued;
  final num interestPaid;
  final num interestDue;
  final num totalDue;
  final List<MonthlyBreakdownRow> monthlyBreakdown;

  const FundingComputation({
    required this.principalTaken,
    required this.principalRepaid,
    required this.principalOutstanding,
    required this.interestAccrued,
    required this.interestPaid,
    required this.interestDue,
    required this.totalDue,
    required this.monthlyBreakdown,
  });

  static const empty = FundingComputation(
    principalTaken: 0,
    principalRepaid: 0,
    principalOutstanding: 0,
    interestAccrued: 0,
    interestPaid: 0,
    interestDue: 0,
    totalDue: 0,
    monthlyBreakdown: [],
  );

  factory FundingComputation.fromJson(Map<String, dynamic> json) => FundingComputation(
        principalTaken: parseNum(json['principal_taken']) ?? 0,
        principalRepaid: parseNum(json['principal_repaid']) ?? 0,
        principalOutstanding: parseNum(json['principal_outstanding']) ?? 0,
        interestAccrued: parseNum(json['interest_accrued']) ?? 0,
        interestPaid: parseNum(json['interest_paid']) ?? 0,
        interestDue: parseNum(json['interest_due']) ?? 0,
        totalDue: parseNum(json['total_due']) ?? 0,
        monthlyBreakdown: (json['monthly_breakdown'] as List<dynamic>? ?? [])
            .map((e) => MonthlyBreakdownRow.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class Funding {
  final int id;
  final String direction;
  final int? funderId;
  final int? borrowerEntityId;
  final int? counterpartyEntityId;
  final int? linkedLoanId;
  final String interestMode;
  final int? interestDueDay;
  final String startDate;
  final String status;
  final String? settledOn;
  final String? notes;
  final FundingLenderRef? funder;
  final FundingEntityRef? borrower;
  final FundingEntityRef? counterparty;
  final FundingLoanRef? linkedLoan;
  final FundingComputation computed;
  final FundingRate? currentRate;

  const Funding({
    required this.id,
    required this.interestMode,
    required this.startDate,
    required this.status,
    required this.computed,
    this.direction = 'BORROWED',
    this.funderId,
    this.borrowerEntityId,
    this.counterpartyEntityId,
    this.linkedLoanId,
    this.interestDueDay,
    this.settledOn,
    this.notes,
    this.funder,
    this.borrower,
    this.counterparty,
    this.linkedLoan,
    this.currentRate,
  });

  /// The name to show for "who this arrangement is with" — the funder for
  /// money borrowed, the counterparty for money lent.
  String get counterpartyName =>
      direction == 'LENT' ? (counterparty?.name ?? '—') : (funder?.name ?? '—');

  factory Funding.fromJson(Map<String, dynamic> json) => Funding(
        id: parseId(json['id'])!,
        direction: json['direction'] as String? ?? 'BORROWED',
        funderId: parseId(json['funder_id']),
        borrowerEntityId: parseId(json['borrower_entity_id']),
        counterpartyEntityId: parseId(json['counterparty_entity_id']),
        linkedLoanId: parseId(json['linked_loan_id']),
        interestMode: json['interest_mode'] as String? ?? 'PERCENT',
        interestDueDay: parseId(json['interest_due_day']),
        startDate: json['start_date'] as String? ?? '',
        status: json['status'] as String? ?? 'OPEN',
        settledOn: json['settled_on'] as String?,
        notes: json['notes'] as String?,
        funder: json['lenders'] != null
            ? FundingLenderRef.fromJson(json['lenders'] as Map<String, dynamic>)
            : null,
        borrower: json['borrower'] != null
            ? FundingEntityRef.fromJson(json['borrower'] as Map<String, dynamic>)
            : null,
        counterparty: json['counterparty'] != null
            ? FundingEntityRef.fromJson(json['counterparty'] as Map<String, dynamic>)
            : null,
        linkedLoan: json['loans'] != null
            ? FundingLoanRef.fromJson(json['loans'] as Map<String, dynamic>)
            : null,
        computed: json['computed'] != null
            ? FundingComputation.fromJson(json['computed'] as Map<String, dynamic>)
            : FundingComputation.empty,
        currentRate: json['current_rate'] != null
            ? FundingRate.fromJson(json['current_rate'] as Map<String, dynamic>)
            : null,
      );
}

class FundingEntry {
  final int id;
  final int fundingId;
  final String entryType;
  final num amount;
  final String entryDate;
  final String? paymentMethod;
  final String? reference;
  final String? description;
  final int? reversesEntryId;
  final bool isReversed;
  final bool isReversal;

  const FundingEntry({
    required this.id,
    required this.fundingId,
    required this.entryType,
    required this.amount,
    required this.entryDate,
    required this.isReversed,
    required this.isReversal,
    this.paymentMethod,
    this.reference,
    this.description,
    this.reversesEntryId,
  });

  bool get canReverse => !isReversed && !isReversal;

  factory FundingEntry.fromJson(Map<String, dynamic> json) => FundingEntry(
        id: parseId(json['id'])!,
        fundingId: parseId(json['funding_id'])!,
        entryType: json['entry_type'] as String? ?? 'PRINCIPAL_TAKEN',
        amount: parseNum(json['amount']) ?? 0,
        entryDate: json['entry_date'] as String? ?? '',
        paymentMethod: json['payment_method'] as String?,
        reference: json['reference'] as String?,
        description: json['description'] as String?,
        reversesEntryId: parseId(json['reverses_entry_id']),
        isReversed: json['is_reversed'] as bool? ?? false,
        isReversal: json['is_reversal'] as bool? ?? false,
      );
}

/// `GET /api/fundings/[id]` payload.
class FundingDetail {
  final Funding funding;
  final List<FundingRate> rates;
  final List<FundingEntry> entries;
  final FundingComputation computed;

  const FundingDetail({
    required this.funding,
    required this.rates,
    required this.entries,
    required this.computed,
  });

  factory FundingDetail.fromJson(Map<String, dynamic> json) => FundingDetail(
        funding: Funding.fromJson(json['funding'] as Map<String, dynamic>),
        rates: (json['rates'] as List<dynamic>? ?? [])
            .map((e) => FundingRate.fromJson(e as Map<String, dynamic>))
            .toList(),
        entries: (json['entries'] as List<dynamic>? ?? [])
            .map((e) => FundingEntry.fromJson(e as Map<String, dynamic>))
            .toList(),
        computed: json['computed'] != null
            ? FundingComputation.fromJson(json['computed'] as Map<String, dynamic>)
            : FundingComputation.empty,
      );
}

/// Portfolio totals for the list screen's stat strip, scoped server-side to
/// the same filters as the page request — computed across every matching
/// funding, not just the current page (see buildFundingSummary in
/// ui-sslogistics' fundings/route.ts).
class FundingSummary {
  final num principalOutstanding;
  final num interestDue;
  final int openCount;

  const FundingSummary({
    required this.principalOutstanding,
    required this.interestDue,
    required this.openCount,
  });

  factory FundingSummary.fromJson(Map<String, dynamic> json) => FundingSummary(
        principalOutstanding: parseNum(json['principalOutstanding']) ?? 0,
        interestDue: parseNum(json['interestDue']) ?? 0,
        openCount: parseId(json['openCount']) ?? 0,
      );
}

class FundingFilters implements ListFilters {
  final String? status;
  final int? funderId;
  final String direction;

  const FundingFilters({this.status, this.funderId, this.direction = 'BORROWED'});

  static const none = FundingFilters();
  static const lent = FundingFilters(direction: 'LENT');

  @override
  bool get isActive => status != null || funderId != null;

  FundingFilters copyWith({
    String? status,
    bool clearStatus = false,
    int? funderId,
    bool clearFunder = false,
    String? direction,
  }) {
    return FundingFilters(
      status: clearStatus ? null : (status ?? this.status),
      funderId: clearFunder ? null : (funderId ?? this.funderId),
      direction: direction ?? this.direction,
    );
  }
}

/// Payload for opening a new funding — the opening rate and opening principal
/// are captured together, so a funding never exists in a state where the
/// interest engine has nothing to compute from.
class FundingDto {
  final String direction;
  final int? funderId;
  final int? counterpartyEntityId;
  final int? borrowerEntityId;
  final int? linkedLoanId;
  final String interestMode;
  final num amount;
  final num? roi;
  final String? roiBasis;
  final num? fixedInterestAmount;
  final int? interestDueDay;
  final String startDate;
  final String? notes;

  const FundingDto({
    required this.interestMode,
    required this.amount,
    required this.startDate,
    this.direction = 'BORROWED',
    this.funderId,
    this.counterpartyEntityId,
    this.borrowerEntityId,
    this.linkedLoanId,
    this.roi,
    this.roiBasis,
    this.fixedInterestAmount,
    this.interestDueDay,
    this.notes,
  });

  Map<String, dynamic> toJson() => {
        'direction': direction,
        'funder_id': funderId,
        'counterparty_entity_id': counterpartyEntityId,
        'borrower_entity_id': borrowerEntityId,
        'linked_loan_id': linkedLoanId,
        'interest_mode': interestMode,
        'amount': amount,
        'roi': roi,
        'roi_basis': roiBasis,
        'fixed_interest_amount': fixedInterestAmount,
        'interest_due_day': interestDueDay,
        'start_date': startDate,
        'notes': notes,
      };
}
