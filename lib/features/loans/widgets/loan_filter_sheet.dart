import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_icons.dart';
import '../../../shared/data/entity_models.dart';
import '../../../shared/data/entity_repository.dart';
import '../../../shared/data/lender_models.dart';
import '../../../shared/data/lender_repository.dart';
import '../../../shared/widgets/search_picker_sheet.dart';
import '../../../shared/widgets/selectable_chip.dart';
import '../../../shared/widgets/tap_field.dart';
import '../data/loan_models.dart';

class LoanFilterSheet extends StatefulWidget {
  final LoanFilters initial;

  const LoanFilterSheet({super.key, required this.initial});

  @override
  State<LoanFilterSheet> createState() => _LoanFilterSheetState();
}

class _LoanFilterSheetState extends State<LoanFilterSheet> {
  late String? _status;
  late bool _overdueOnly;
  Entity? _borrower;
  Lender? _lender;

  List<Entity> _entities = [];
  List<Lender> _lenders = [];
  bool _loadingOptions = true;

  @override
  void initState() {
    super.initState();
    _status = widget.initial.status;
    _overdueOnly = widget.initial.overdueOnly;
    _loadOptions();
  }

  Future<void> _loadOptions() async {
    try {
      final entities = await EntityRepository().fetchAll();
      final lenders = await LenderRepository().fetchAll(lenderKind: 'INSTITUTION');
      if (!mounted) return;
      setState(() {
        _entities = entities;
        _lenders = lenders;
        if (widget.initial.borrowerEntityId != null) {
          final match = entities.where((e) => e.id == widget.initial.borrowerEntityId);
          if (match.isNotEmpty) _borrower = match.first;
        }
        if (widget.initial.lenderId != null) {
          final match = lenders.where((l) => l.id == widget.initial.lenderId);
          if (match.isNotEmpty) _lender = match.first;
        }
        _loadingOptions = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingOptions = false);
    }
  }

  Future<void> _pickBorrower() async {
    final result = await showSearchPicker<Entity>(
      context,
      title: 'Filter by borrower',
      icon: AppIcons.building2,
      items: _entities,
      selected: _borrower,
      searchHint: 'Search firms and people...',
      labelBuilder: (e) => e.name,
      subtitleBuilder: (e) => e.entityKind == 'FIRM' ? 'Firm' : 'Person',
      matcher: (e, q) => e.name.toLowerCase().contains(q),
      clearLabel: 'All borrowers',
    );
    if (!mounted || result == null) return;
    setState(() => _borrower = result is ClearPick ? null : result as Entity);
  }

  Future<void> _pickLender() async {
    final result = await showSearchPicker<Lender>(
      context,
      title: 'Filter by lender',
      icon: AppIcons.landmark,
      items: _lenders,
      selected: _lender,
      searchHint: 'Search lenders...',
      labelBuilder: (l) => l.name,
      subtitleBuilder: (l) => l.phone ?? '',
      matcher: (l, q) => l.name.toLowerCase().contains(q),
      clearLabel: 'All lenders',
    );
    if (!mounted || result == null) return;
    setState(() => _lender = result is ClearPick ? null : result as Lender);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.border;

    return Material(
      color: isDark ? AppColors.darkCardBg : Colors.white,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: borderColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Filters',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context, LoanFilters.none),
                    child: const Text('Clear all'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const FieldLabel('Status'),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  SelectableChip(
                    label: 'All',
                    selected: _status == null,
                    onTap: () => setState(() => _status = null),
                  ),
                  for (final s in kLoanStatuses)
                    SelectableChip(
                      label: loanStatusLabel(s),
                      selected: _status == s,
                      onTap: () => setState(() => _status = s),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              const FieldLabel('Borrower'),
              TapField(
                value: _borrower?.name ?? 'All borrowers',
                icon: AppIcons.building2,
                muted: _borrower == null,
                enabled: !_loadingOptions,
                onTap: _pickBorrower,
                onClear: _borrower != null ? () => setState(() => _borrower = null) : null,
              ),
              const SizedBox(height: 14),
              const FieldLabel('Lender'),
              TapField(
                value: _lender?.name ?? 'All lenders',
                icon: AppIcons.landmark,
                muted: _lender == null,
                enabled: !_loadingOptions,
                onTap: _pickLender,
                onClear: _lender != null ? () => setState(() => _lender = null) : null,
              ),
              const SizedBox(height: 14),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Overdue only', style: TextStyle(fontWeight: FontWeight.w700)),
                value: _overdueOnly,
                onChanged: (v) => setState(() => _overdueOnly = v),
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () => Navigator.pop(
                  context,
                  LoanFilters(
                    status: _status,
                    borrowerEntityId: _borrower?.id,
                    lenderId: _lender?.id,
                    overdueOnly: _overdueOnly,
                  ),
                ),
                child: const Text('Apply Filters'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
