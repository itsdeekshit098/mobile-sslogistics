import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:mobile_sslogistics/core/constants/app_icons.dart';

import '../../../core/constants/app_colors.dart';
import '../../../shared/utils/validated_field.dart';
import '../../../shared/widgets/form_error_banner.dart';
import '../../../shared/widgets/server_error_banner.dart';
import '../data/repair_models.dart';
import '../providers/repair_provider.dart';
import 'create_repair_sheet.dart';
import 'parts_editor.dart';

class EditRepairSheet extends ConsumerStatefulWidget {
  final RepairRecord record;

  const EditRepairSheet({super.key, required this.record});

  @override
  ConsumerState<EditRepairSheet> createState() => _EditRepairSheetState();
}

class _EditRepairSheetState extends ConsumerState<EditRepairSheet> {
  late final _costCtrl = TextEditingController(text: _trimZeros(widget.record.cost));
  late final _descCtrl = TextEditingController(text: widget.record.description ?? '');
  final _partsKey = GlobalKey<PartsEditorState>();

  late List<String> _issues = List.of(widget.record.issues);
  Technician? _technician;
  late String _status = widget.record.status;
  bool _isSubmitting = false;
  bool _techInitialized = false;
  int _errorCount = 0;
  // Shown as a banner inside the sheet rather than a SnackBar — a SnackBar
  // anchors to the screen underneath and renders hidden behind this modal
  // bottom sheet, so the user never sees it even though it technically fired.
  String? _serverError;

  final _issuesSectionKey = GlobalKey();
  final _technicianSectionKey = GlobalKey();
  final _costFieldKey = GlobalKey<FormFieldState>();
  final _costFocus = FocusNode();
  final _partsSectionKey = GlobalKey();

  /// Ordered top-to-bottom validated fields, used to find and jump to the
  /// first one currently showing an error. Manual (non-Form) checks here
  /// mirror the imperative validation in `_submit()` below.
  List<ValidatedField> get _validatedFields => [
        ValidatedField(
          key: _issuesSectionKey,
          hasError: () => _issues.isEmpty,
        ),
        ValidatedField(
          key: _technicianSectionKey,
          hasError: () => _technician == null,
        ),
        ValidatedField(
          key: _costFieldKey,
          hasError: () {
            final cost = double.tryParse(_costCtrl.text);
            return cost == null || cost < 0;
          },
          focusNode: _costFocus,
        ),
        ValidatedField(
          key: _partsKey.currentState?.firstInvalidRowKey ?? _partsSectionKey,
          hasError: () => _partsKey.currentState?.hasInvalidRow ?? false,
        ),
      ];

  static String _trimZeros(double v) => v == v.roundToDouble() ? v.toInt().toString() : '$v';

  @override
  void dispose() {
    _costCtrl.dispose();
    _descCtrl.dispose();
    _costFocus.dispose();
    super.dispose();
  }

  void _initTechnician(List<Technician> technicians) {
    if (_techInitialized) return;
    _techInitialized = true;
    try {
      _technician = technicians.firstWhere((t) => t.id == widget.record.technicianId);
    } catch (_) {
      _technician = null;
    }
  }

  Future<void> _pickIssues(Map<String, List<String>> issueOptions) async {
    final picked = await showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => IssuesPickerSheet(
        category: widget.record.category,
        options: issueOptions[widget.record.category] ?? const [],
        selected: _issues,
      ),
    );
    if (picked != null) setState(() => _issues = picked);
  }

  Future<void> _pickTechnician(List<Technician> technicians) async {
    final picked = await showModalBottomSheet<Technician>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => TechnicianPickerSheet(technicians: technicians, selected: _technician),
    );
    if (picked != null) setState(() => _technician = picked);
  }

  String _firstErrorMessage() {
    if (_issues.isEmpty) return 'Please select at least one issue';
    if (_technician == null) return 'Please select a technician';
    final cost = double.tryParse(_costCtrl.text);
    if (cost == null || cost < 0) return 'Please enter a valid cost';
    return 'Please complete or remove incomplete parts';
  }

  Future<void> _submit() async {
    // No `Form` ancestor here — validate the cost field directly so its
    // border/error text paints, and flip per-row `showErrors` on the parts
    // editor so an incomplete row is visibly red once scrolled into view.
    _costFieldKey.currentState?.validate();
    final parts = _partsKey.currentState?.collectParts();

    final fields = _validatedFields;
    final errorCount = countFormErrors(fields);
    if (errorCount > 0) {
      setState(() => _errorCount = errorCount);
      await scrollToFirstError(fields);
      _showError(_firstErrorMessage());
      return;
    }
    setState(() {
      _errorCount = 0;
      _serverError = null;
    });

    final cost = double.parse(_costCtrl.text);

    setState(() => _isSubmitting = true);
    try {
      final dto = UpdateRepairDto(
        id: widget.record.id,
        description: _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
        cost: cost,
        technicianId: _technician!.id,
        status: _status,
        issues: _issues,
        parts: parts ?? const [],
      );
      await ref.read(repairListProvider.notifier).updateRecord(dto);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Repair record updated'), backgroundColor: AppColors.success),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        _showError(e.toString().replaceFirst('Exception: ', ''));
      }
    }
  }

  void _showError(String message) {
    setState(() => _serverError = message);
  }

  @override
  Widget build(BuildContext context) {
    final issueOptionsAsync = ref.watch(repairIssueOptionsProvider);
    final techniciansAsync = ref.watch(techniciansProvider);
    final dateFmt = DateFormat('dd MMM yyyy');
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final date = DateTime.tryParse(widget.record.repairDate)?.toLocal();
    final isOpen = _status == repairStatusOpen;

    return Material(
      color: isDark ? AppColors.darkCardBg : Colors.white,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 10),
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkBorder : AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              children: [
                Text(
                  'Edit Repair Record',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                  ),
                ),
                const Spacer(),
                IconButton(icon: const Icon(AppIcons.x, size: 20), onPressed: () => Navigator.pop(context)),
              ],
            ),
          ),
          const Divider(height: 1),
          if (_errorCount > 0) FormErrorBanner(count: _errorCount),
          if (_serverError != null) ServerErrorBanner(message: _serverError!),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: FieldSection(
                          label: 'Vehicle',
                          child: TapField(
                            value: widget.record.vehicleNumber,
                            icon: AppIcons.truck,
                            onTap: null,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FieldSection(
                          label: 'Date',
                          child: TapField(
                            value: date != null ? dateFmt.format(date) : widget.record.repairDate,
                            icon: AppIcons.calendar,
                            onTap: null,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  FieldSection(
                    label: 'Category',
                    child: TapField(
                      value: widget.record.categoryLabel,
                      icon: AppIcons.wrench,
                      onTap: null,
                    ),
                  ),
                  const SizedBox(height: 14),
                  FieldSection(
                    label: 'Status',
                    child: StatusToggle(
                      isOpen: isOpen,
                      onChanged: (open) => setState(() => _status = open ? repairStatusOpen : repairStatusClosed),
                    ),
                  ),
                  const SizedBox(height: 14),
                  FieldSection(
                    key: _issuesSectionKey,
                    label: 'Issues *',
                    child: issueOptionsAsync.when(
                      loading: () => const LinearProgressIndicator(),
                      error: (e, _) => Text('Error loading issues', style: TextStyle(color: AppColors.error)),
                      data: (options) => TapField(
                        value: _issues.isEmpty ? 'Select issues' : _issues.join(', '),
                        icon: AppIcons.wrench,
                        muted: _issues.isEmpty,
                        onTap: () => _pickIssues(options),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  FieldSection(
                    key: _technicianSectionKey,
                    label: 'Technician *',
                    child: techniciansAsync.when(
                      loading: () => const LinearProgressIndicator(),
                      error: (e, _) => Text('Error loading technicians', style: TextStyle(color: AppColors.error)),
                      data: (technicians) {
                        _initTechnician(technicians);
                        return TapField(
                          value: _technician?.name ?? 'Select technician',
                          icon: AppIcons.userCog,
                          muted: _technician == null,
                          onTap: () => _pickTechnician(technicians),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 14),
                  FieldSection(
                    label: 'Cost (₹) *',
                    child: TextFormField(
                      key: _costFieldKey,
                      controller: _costCtrl,
                      focusNode: _costFocus,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: inputDecor(context, hint: 'e.g. 2500'),
                      validator: (v) {
                        final cost = double.tryParse(v ?? '');
                        if (cost == null || cost < 0) return 'Enter a valid cost';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(height: 14),
                  FieldSection(
                    label: 'Description',
                    child: TextFormField(
                      controller: _descCtrl,
                      maxLines: 2,
                      decoration: inputDecor(context, hint: 'Additional notes...'),
                    ),
                  ),
                  const SizedBox(height: 18),
                  FieldSection(
                    key: _partsSectionKey,
                    label: 'Parts',
                    child: PartsEditor(key: _partsKey, initialParts: widget.record.parts),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: EdgeInsets.fromLTRB(20, 12, 20, 12 + MediaQuery.of(context).viewInsets.bottom),
            child: ElevatedButton(
              onPressed: _isSubmitting ? null : _submit,
              child: _isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                    )
                  : const Text('Save Changes'),
            ),
          ),
        ],
      ),
    );
  }
}

class StatusToggle extends StatelessWidget {
  final bool isOpen;
  final ValueChanged<bool> onChanged;

  const StatusToggle({super.key, required this.isOpen, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(right: 8),
            child: _StatusOption(
              label: 'Open',
              color: AppColors.warning,
              selected: isOpen,
              onTap: () => onChanged(true),
              isDark: isDark,
            ),
          ),
        ),
        Expanded(
          child: _StatusOption(
            label: 'Closed',
            color: AppColors.success,
            selected: !isOpen,
            onTap: () => onChanged(false),
            isDark: isDark,
          ),
        ),
      ],
    );
  }
}

class _StatusOption extends StatelessWidget {
  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;
  final bool isDark;

  const _StatusOption({
    required this.label,
    required this.color,
    required this.selected,
    required this.onTap,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? color : (isDark ? AppColors.darkCardBg : Colors.white),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: selected ? color : (isDark ? AppColors.darkBorder : AppColors.border)),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: selected ? Colors.white : (isDark ? AppColors.darkTextSecondary : AppColors.textSecondary),
            ),
          ),
        ),
      ),
    );
  }
}
