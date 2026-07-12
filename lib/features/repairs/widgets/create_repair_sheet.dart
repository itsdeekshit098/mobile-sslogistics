import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:mobile_sslogistics/core/constants/app_icons.dart';

import '../../../core/constants/app_colors.dart';
import '../../../shared/models/vehicle_model.dart';
import '../../../shared/utils/validated_field.dart';
import '../../../shared/widgets/form_error_banner.dart';
import '../../../shared/widgets/server_error_banner.dart';
import '../../diesel/providers/vehicle_provider.dart';
import '../data/repair_models.dart';
import '../providers/repair_provider.dart';
import 'parts_editor.dart';

class CreateRepairSheet extends ConsumerStatefulWidget {
  const CreateRepairSheet({super.key});

  @override
  ConsumerState<CreateRepairSheet> createState() => _CreateRepairSheetState();
}

class _CreateRepairSheetState extends ConsumerState<CreateRepairSheet> {
  final _costCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _partsKey = GlobalKey<PartsEditorState>();

  Vehicle? _vehicle;
  DateTime _date = DateTime.now();
  String _category = repairCategoryElectrical;
  List<String> _issues = [];
  Technician? _technician;
  bool _isSubmitting = false;
  int _errorCount = 0;
  // Shown as a banner inside the sheet rather than a SnackBar — a SnackBar
  // anchors to the screen underneath and renders hidden behind this modal
  // bottom sheet, so the user never sees it even though it technically fired.
  String? _serverError;

  final _vehicleSectionKey = GlobalKey();
  final _issuesSectionKey = GlobalKey();
  final _technicianSectionKey = GlobalKey();
  final _costFieldKey = GlobalKey<FormFieldState>();
  final _costFocus = FocusNode();
  final _partsSectionKey = GlobalKey();

  /// Ordered top-to-bottom validated fields, used to find and jump to the
  /// first one currently showing an error. Manual (non-Form) checks here
  /// mirror the imperative validation in `_submit()` below.
  List<ValidatedField> get _validatedFields => [
        ValidatedField(key: _vehicleSectionKey, hasError: () => _vehicle == null),
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

  @override
  void dispose() {
    _costCtrl.dispose();
    _descCtrl.dispose();
    _costFocus.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickVehicle(List<Vehicle> vehicles) async {
    final picked = await showModalBottomSheet<Vehicle>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => VehiclePickerSheet(vehicles: vehicles, selected: _vehicle),
    );
    if (picked != null) setState(() => _vehicle = picked);
  }

  void _setCategory(String category) {
    if (category == _category) return;
    setState(() {
      _category = category;
      _issues = [];
    });
  }

  Future<void> _pickIssues(Map<String, List<String>> issueOptions) async {
    final picked = await showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => IssuesPickerSheet(
        category: _category,
        options: issueOptions[_category] ?? const [],
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
      final dto = CreateRepairDto(
        vehicleId: _vehicle!.id,
        repairDate: _date.toUtc().toIso8601String(),
        category: _category,
        issues: _issues,
        description: _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
        cost: cost,
        technicianId: _technician!.id,
        parts: parts ?? const [],
      );
      await ref.read(repairListProvider.notifier).createRecord(dto);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Repair record added'), backgroundColor: AppColors.success),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        _showError(e.toString().replaceFirst('Exception: ', ''));
      }
    }
  }

  String _firstErrorMessage() {
    if (_vehicle == null) return 'Please select a vehicle';
    if (_issues.isEmpty) return 'Please select at least one issue';
    if (_technician == null) return 'Please select a technician';
    final cost = double.tryParse(_costCtrl.text);
    if (cost == null || cost < 0) return 'Please enter a valid cost';
    return 'Please complete or remove incomplete parts';
  }

  void _showError(String message) {
    setState(() => _serverError = message);
  }

  @override
  Widget build(BuildContext context) {
    final vehiclesAsync = ref.watch(vehiclesProvider);
    final issueOptionsAsync = ref.watch(repairIssueOptionsProvider);
    final techniciansAsync = ref.watch(techniciansProvider);
    final dateFmt = DateFormat('dd MMM yyyy');
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
                  'Add Repair Record',
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
                  FieldSection(
                    key: _vehicleSectionKey,
                    label: 'Vehicle *',
                    child: vehiclesAsync.when(
                      loading: () => const LinearProgressIndicator(),
                      error: (e, _) => Text('Error loading vehicles', style: TextStyle(color: AppColors.error)),
                      data: (vehicles) => TapField(
                        value: _vehicle?.plateNumber ?? 'Select vehicle',
                        icon: AppIcons.truck,
                        muted: _vehicle == null,
                        onTap: () => _pickVehicle(vehicles),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  FieldSection(
                    label: 'Repair Date *',
                    child: TapField(
                      value: dateFmt.format(_date),
                      icon: AppIcons.calendar,
                      onTap: _pickDate,
                    ),
                  ),
                  const SizedBox(height: 14),
                  FieldSection(
                    label: 'Category *',
                    child: CategoryToggle(selected: _category, onSelected: _setCategory),
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
                      data: (technicians) => TapField(
                        value: _technician?.name ?? 'Select technician',
                        icon: AppIcons.userCog,
                        muted: _technician == null,
                        onTap: () => _pickTechnician(technicians),
                      ),
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
                    child: PartsEditor(key: _partsKey),
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
                  : const Text('Add Repair Record'),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Shared field widgets, reused by edit_repair_sheet.dart ──────────────────

class FieldSection extends StatelessWidget {
  final String label;
  final Widget child;
  const FieldSection({super.key, required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isRequired = label.endsWith(' *');
    final baseLabel = isRequired ? label.substring(0, label.length - 2) : label;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text.rich(
          TextSpan(
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
            ),
            children: [
              TextSpan(text: baseLabel),
              if (isRequired) const TextSpan(text: ' *', style: TextStyle(color: AppColors.error)),
            ],
          ),
        ),
        const SizedBox(height: 5),
        child,
      ],
    );
  }
}

class TapField extends StatelessWidget {
  final String value;
  final IconData icon;
  final VoidCallback? onTap;
  final bool muted;

  const TapField({super.key, required this.value, required this.icon, required this.onTap, this.muted = false});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final mutedColor = isDark ? AppColors.darkTextMuted : AppColors.textMuted;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
        decoration: BoxDecoration(
          border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(icon, size: 15, color: mutedColor),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  color: muted ? mutedColor : (isDark ? AppColors.darkTextPrimary : AppColors.textPrimary),
                ),
              ),
            ),
            if (onTap != null) Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: mutedColor),
          ],
        ),
      ),
    );
  }
}

class CategoryToggle extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onSelected;

  const CategoryToggle({super.key, required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [repairCategoryElectrical, repairCategoryMechanical].map((cat) {
        final isSelected = selected == cat;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: cat == repairCategoryElectrical ? 8 : 0),
            child: InkWell(
              onTap: () => onSelected(cat),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.primary : (isDark ? AppColors.darkCardBg : Colors.white),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSelected ? AppColors.primary : (isDark ? AppColors.darkBorder : AppColors.border),
                  ),
                ),
                child: Center(
                  child: Text(
                    repairCategoryLabels[cat]!,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: isSelected ? Colors.white : (isDark ? AppColors.darkTextSecondary : AppColors.textSecondary),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

InputDecoration inputDecor(BuildContext context, {String? hint}) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final borderColor = isDark ? AppColors.darkBorder : AppColors.border;
  return InputDecoration(
    hintText: hint,
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    isDense: true,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: borderColor)),
    enabledBorder:
        OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: borderColor)),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: AppColors.primary, width: 2),
    ),
  );
}

// ── Picker sheets shared with edit_repair_sheet.dart ─────────────────────────

class VehiclePickerSheet extends StatefulWidget {
  final List<Vehicle> vehicles;
  final Vehicle? selected;

  const VehiclePickerSheet({super.key, required this.vehicles, this.selected});

  @override
  State<VehiclePickerSheet> createState() => _VehiclePickerSheetState();
}

class _VehiclePickerSheetState extends State<VehiclePickerSheet> {
  String _query = '';

  List<Vehicle> get _filtered {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return widget.vehicles;
    return widget.vehicles
        .where((v) => [v.plateNumber, v.make, v.model].whereType<String>().join(' ').toLowerCase().contains(q))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return PickerShell(
      title: 'Select vehicle (${widget.vehicles.length})',
      searchHint: 'Search vehicle number, make, model',
      onSearch: (v) => setState(() => _query = v),
      itemCount: filtered.length,
      itemBuilder: (_, i) {
        final v = filtered[i];
        final selected = widget.selected?.id == v.id;
        return ListTile(
          dense: true,
          leading: Icon(AppIcons.truck, color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary),
          title: Text(
            v.plateNumber,
            style: TextStyle(
              fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
              color: selected ? AppColors.primary : (isDark ? AppColors.darkTextPrimary : AppColors.textPrimary),
            ),
          ),
          subtitle: [v.make, v.model].whereType<String>().join(' ').isEmpty
              ? null
              : Text([v.make, v.model].whereType<String>().join(' ')),
          trailing: selected ? const Icon(Icons.check_rounded, color: AppColors.primary) : null,
          onTap: () => Navigator.pop(context, v),
        );
      },
      emptyLabel: 'No vehicles found',
    );
  }
}

class TechnicianPickerSheet extends StatefulWidget {
  final List<Technician> technicians;
  final Technician? selected;

  const TechnicianPickerSheet({super.key, required this.technicians, this.selected});

  @override
  State<TechnicianPickerSheet> createState() => _TechnicianPickerSheetState();
}

class _TechnicianPickerSheetState extends State<TechnicianPickerSheet> {
  String _query = '';

  List<Technician> get _filtered {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return widget.technicians;
    return widget.technicians
        .where((t) => [t.name, ...t.specializations].join(' ').toLowerCase().contains(q))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final mutedColor = isDark ? AppColors.darkTextMuted : AppColors.textMuted;
    return PickerShell(
      title: 'Select technician',
      searchHint: 'Search name, specialization',
      onSearch: (v) => setState(() => _query = v),
      itemCount: filtered.length,
      itemBuilder: (_, i) {
        final t = filtered[i];
        final selected = widget.selected?.id == t.id;
        return ListTile(
          dense: true,
          enabled: t.isActive,
          leading: Icon(AppIcons.userCog,
              color: t.isActive ? (isDark ? AppColors.darkTextSecondary : AppColors.textSecondary) : mutedColor),
          title: Text(
            t.isActive ? t.name : '${t.name} (inactive)',
            style: TextStyle(
              fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
              color: !t.isActive
                  ? mutedColor
                  : selected
                      ? AppColors.primary
                      : (isDark ? AppColors.darkTextPrimary : AppColors.textPrimary),
            ),
          ),
          subtitle: t.specializations.isNotEmpty ? Text(t.specializations.join(', ')) : null,
          trailing: selected ? const Icon(Icons.check_rounded, color: AppColors.primary) : null,
          onTap: t.isActive ? () => Navigator.pop(context, t) : null,
        );
      },
      emptyLabel: 'No technicians found',
    );
  }
}

class IssuesPickerSheet extends ConsumerStatefulWidget {
  final String category;
  final List<String> options;
  final List<String> selected;

  const IssuesPickerSheet({super.key, required this.category, required this.options, required this.selected});

  @override
  ConsumerState<IssuesPickerSheet> createState() => _IssuesPickerSheetState();
}

class _IssuesPickerSheetState extends ConsumerState<IssuesPickerSheet> {
  late final List<String> _selected = List.of(widget.selected);
  late final List<String> _options = List.of(widget.options);
  final _newIssueCtrl = TextEditingController();
  bool _adding = false;
  // Shown as a banner inside the sheet rather than a SnackBar — a SnackBar
  // anchors to the screen underneath and renders hidden behind this modal
  // bottom sheet, so the user never sees it even though it technically fired.
  String? _serverError;

  @override
  void dispose() {
    _newIssueCtrl.dispose();
    super.dispose();
  }

  Future<void> _addNew() async {
    final name = _newIssueCtrl.text.trim();
    if (name.isEmpty) return;
    setState(() {
      _adding = true;
      _serverError = null;
    });
    try {
      final repo = ref.read(repairRepositoryProvider);
      await repo.addIssueOption(widget.category, name);
      ref.invalidate(repairIssueOptionsProvider);
      setState(() {
        if (!_options.contains(name)) _options.add(name);
        if (!_selected.contains(name)) _selected.add(name);
        _newIssueCtrl.clear();
        _adding = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _adding = false;
          _serverError = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: keyboardHeight),
      child: Material(
        color: isDark ? AppColors.darkCardBg : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkBorder : AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 8, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${repairCategoryLabels[widget.category]} issues',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, _selected),
                      child: const Text('Done'),
                    ),
                  ],
                ),
              ),
              if (_serverError != null) ServerErrorBanner(message: _serverError!),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 320),
                child: _options.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Text('No issue options yet',
                            style: TextStyle(
                                color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary)),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        itemCount: _options.length,
                        itemBuilder: (_, i) {
                          final issue = _options[i];
                          final checked = _selected.contains(issue);
                          return CheckboxListTile(
                            dense: true,
                            value: checked,
                            title: Text(issue),
                            controlAffinity: ListTileControlAffinity.leading,
                            onChanged: (v) => setState(() {
                              if (v == true) {
                                _selected.add(issue);
                              } else {
                                _selected.remove(issue);
                              }
                            }),
                          );
                        },
                      ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _newIssueCtrl,
                        decoration: inputDecor(context, hint: 'Add a new issue'),
                        onSubmitted: (_) => _addNew(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: _adding ? null : _addNew,
                      icon: _adding
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(AppIcons.plus),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class PickerShell extends StatelessWidget {
  final String title;
  final String searchHint;
  final ValueChanged<String> onSearch;
  final int itemCount;
  final Widget Function(BuildContext, int) itemBuilder;
  final String emptyLabel;

  const PickerShell({
    super.key,
    required this.title,
    required this.searchHint,
    required this.onSearch,
    required this.itemCount,
    required this.itemBuilder,
    required this.emptyLabel,
  });

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final keyboardHeight = media.viewInsets.bottom;
    final maxListHeight = (media.size.height - keyboardHeight) * 0.42;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.border;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: keyboardHeight),
      child: Material(
        color: isDark ? AppColors.darkCardBg : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: borderColor, borderRadius: BorderRadius.circular(2)),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    title,
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: TextField(
                  autofocus: true,
                  onChanged: onSearch,
                  decoration: InputDecoration(
                    hintText: searchHint,
                    prefixIcon: const Icon(Icons.search_rounded, size: 20),
                    isDense: true,
                    filled: true,
                    fillColor: isDark ? AppColors.darkPageBg : AppColors.pageBg,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: borderColor),
                    ),
                  ),
                ),
              ),
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: maxListHeight.clamp(160.0, 420.0)),
                child: itemCount == 0
                    ? Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Text(emptyLabel,
                            style: TextStyle(
                                color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary)),
                      )
                    : ListView.builder(shrinkWrap: true, itemCount: itemCount, itemBuilder: itemBuilder),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}
