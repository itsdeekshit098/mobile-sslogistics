import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:mobile_sslogistics/core/constants/app_icons.dart';

import '../../../core/constants/app_colors.dart';
import '../data/repair_models.dart';
import '../providers/repair_provider.dart';

final _dateFmt = DateFormat('dd MMM yyyy');
final _isoFmt = DateFormat('yyyy-MM-dd');
final _moneyFmt = NumberFormat('#,##0.00', 'en_IN');

/// One editable part row's mutable form state.
class _PartFormEntry {
  int? id;
  String partName;
  Vendor? vendor;
  final TextEditingController costCtrl;
  DateTime? purchaseDate;
  final TextEditingController durationCtrl;
  String unit;
  final TextEditingController notesCtrl;
  bool showErrors = false;
  // Lets the parent sheet scroll this row into view when it's the first
  // invalid one on submit — Scrollable.ensureVisible needs a widget key,
  // not just the boolean `isValid` check below.
  final GlobalKey rowKey = GlobalKey();

  _PartFormEntry({
    this.id,
    this.partName = '',
    this.vendor,
    double? cost,
    this.purchaseDate,
    int? duration,
    this.unit = warrantyUnitMonths,
    String notes = '',
  })  : costCtrl = TextEditingController(text: cost != null ? _trimZeros(cost) : ''),
        durationCtrl = TextEditingController(text: duration?.toString() ?? ''),
        notesCtrl = TextEditingController(text: notes);

  factory _PartFormEntry.fromExisting(RepairPart part, List<Vendor> vendors) {
    Vendor? vendor;
    try {
      vendor = vendors.firstWhere((v) => v.id == part.vendorId);
    } catch (_) {
      vendor = part.vendorName != null
          ? Vendor(id: part.vendorId, name: part.vendorName!, phone: part.vendorPhone, location: part.vendorLocation)
          : null;
    }
    return _PartFormEntry(
      id: part.id,
      partName: part.partName,
      vendor: vendor,
      cost: part.cost,
      purchaseDate: DateTime.tryParse(part.purchaseDate),
      duration: part.warrantyDuration,
      unit: part.warrantyDurationUnit,
      notes: part.notes ?? '',
    );
  }

  DateTime? get expiryPreview {
    if (purchaseDate == null) return null;
    final n = int.tryParse(durationCtrl.text);
    if (n == null || n <= 0) return null;
    return unit == warrantyUnitYears
        ? DateTime(purchaseDate!.year + n, purchaseDate!.month, purchaseDate!.day)
        : DateTime(purchaseDate!.year, purchaseDate!.month + n, purchaseDate!.day);
  }

  bool get isValid =>
      partName.isNotEmpty &&
      vendor != null &&
      double.tryParse(costCtrl.text) != null &&
      double.parse(costCtrl.text) >= 0 &&
      purchaseDate != null &&
      (int.tryParse(durationCtrl.text) ?? 0) > 0;

  RepairPart toRepairPart() => RepairPart(
        id: id,
        partName: partName,
        vendorId: vendor!.id,
        cost: double.parse(costCtrl.text),
        purchaseDate: _isoFmt.format(purchaseDate!),
        warrantyDuration: int.parse(durationCtrl.text),
        warrantyDurationUnit: unit,
        notes: notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
      );

  void dispose() {
    costCtrl.dispose();
    durationCtrl.dispose();
    notesCtrl.dispose();
  }
}

/// Add/edit/remove parts on a repair record. Owns its own form state;
/// call [PartsEditorState.collectParts] on submit to validate and retrieve
/// the current list, or null if any row is incomplete.
class PartsEditor extends ConsumerStatefulWidget {
  final List<RepairPart> initialParts;

  const PartsEditor({super.key, this.initialParts = const []});

  @override
  ConsumerState<PartsEditor> createState() => PartsEditorState();
}

class PartsEditorState extends ConsumerState<PartsEditor> {
  final List<_PartFormEntry> _entries = [];
  bool _seeded = false;

  @override
  void dispose() {
    for (final e in _entries) {
      e.dispose();
    }
    super.dispose();
  }

  void _seedFromExisting(List<Vendor> vendors) {
    if (_seeded) return;
    _seeded = true;
    for (final p in widget.initialParts) {
      _entries.add(_PartFormEntry.fromExisting(p, vendors));
    }
  }

  /// Validates every row; returns the parts list, or null (and shows row
  /// errors) if any row is incomplete.
  List<RepairPart>? collectParts() {
    var allValid = true;
    for (final e in _entries) {
      if (!e.isValid) allValid = false;
    }
    if (!allValid) {
      setState(() {
        for (final e in _entries) {
          e.showErrors = true;
        }
      });
      return null;
    }
    return _entries.map((e) => e.toRepairPart()).toList();
  }

  /// Whether any row is currently incomplete — checked by the parent sheet
  /// to include the parts editor in its own validated-fields list.
  bool get hasInvalidRow => _entries.any((e) => !e.isValid);

  /// The first incomplete row's key, for the parent sheet to scroll to.
  GlobalKey? get firstInvalidRowKey {
    for (final e in _entries) {
      if (!e.isValid) return e.rowKey;
    }
    return null;
  }

  void _addRow() {
    setState(() => _entries.add(_PartFormEntry()));
  }

  void _removeRow(_PartFormEntry entry) {
    setState(() {
      _entries.remove(entry);
      entry.dispose();
    });
  }

  @override
  Widget build(BuildContext context) {
    final vendorsAsync = ref.watch(vendorsProvider);
    final partOptionsAsync = ref.watch(partOptionsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return vendorsAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: LinearProgressIndicator(),
      ),
      error: (e, _) => Text('Error loading vendors', style: TextStyle(color: AppColors.error)),
      data: (vendors) {
        _seedFromExisting(vendors);
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkPageBg : AppColors.pageBg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final entry in _entries) ...[
                _PartRow(
                  key: entry.rowKey,
                  entry: entry,
                  vendors: vendors,
                  partOptions: partOptionsAsync.valueOrNull ?? const [],
                  onRemove: () => _removeRow(entry),
                  onChanged: () => setState(() {}),
                ),
                const SizedBox(height: 12),
              ],
              TextButton.icon(
                onPressed: _addRow,
                style: TextButton.styleFrom(
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                ),
                icon: const Icon(AppIcons.plus, size: 16),
                label: const Text('Add part'),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PartRow extends ConsumerWidget {
  final _PartFormEntry entry;
  final List<Vendor> vendors;
  final List<PartOption> partOptions;
  final VoidCallback onRemove;
  final VoidCallback onChanged;

  const _PartRow({
    super.key,
    required this.entry,
    required this.vendors,
    required this.partOptions,
    required this.onRemove,
    required this.onChanged,
  });

  Future<void> _pickPartName(BuildContext context, WidgetRef ref) async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SearchAddSheet(
        title: 'Select part',
        options: partOptions.map((p) => p.name).toList(),
        selected: entry.partName,
        onAddNew: (name) async {
          final result = await ref.read(repairRepositoryProvider).addPartOption(name);
          ref.invalidate(partOptionsProvider);
          return result?.name ?? name;
        },
      ),
    );
    if (picked != null) {
      entry.partName = picked;
      onChanged();
    }
  }

  Future<void> _pickVendor(BuildContext context) async {
    final picked = await showModalBottomSheet<Vendor>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _VendorPickerSheet(vendors: vendors, selected: entry.vendor),
    );
    if (picked != null) {
      entry.vendor = picked;
      onChanged();
    }
  }

  Future<void> _pickDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: entry.purchaseDate ?? DateTime.now(),
      firstDate: DateTime(2015),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      entry.purchaseDate = picked;
      onChanged();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.border;
    final showErr = entry.showErrors;
    final expiry = entry.expiryPreview;

    InputDecoration decor(String hint) => InputDecoration(
          hintText: hint,
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          isDense: true,
          filled: true,
          fillColor: isDark ? AppColors.darkCardBg : Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: borderColor),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: borderColor),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: AppColors.primary, width: 2),
          ),
        );

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCardBg : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: _RowTapField(
                  value: entry.partName.isEmpty ? 'Select part' : entry.partName,
                  icon: AppIcons.wrench,
                  muted: entry.partName.isEmpty,
                  hasError: showErr && entry.partName.isEmpty,
                  onTap: () => _pickPartName(context, ref),
                ),
              ),
              IconButton(
                onPressed: onRemove,
                icon: const Icon(AppIcons.trash2, size: 18, color: AppColors.error),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _RowTapField(
            value: entry.vendor?.name ?? 'Select vendor',
            icon: Icons.storefront_outlined,
            muted: entry.vendor == null,
            hasError: showErr && entry.vendor == null,
            onTap: () => _pickVendor(context),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: entry.costCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: decor('Cost ₹').copyWith(
                    errorText: showErr && double.tryParse(entry.costCtrl.text) == null
                        ? 'Required'
                        : null,
                  ),
                  onChanged: (_) => onChanged(),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _RowTapField(
                  value: entry.purchaseDate != null ? _dateFmt.format(entry.purchaseDate!) : 'Purchase date',
                  icon: AppIcons.calendar,
                  muted: entry.purchaseDate == null,
                  hasError: showErr && entry.purchaseDate == null,
                  onTap: () => _pickDate(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: entry.durationCtrl,
                  keyboardType: TextInputType.number,
                  decoration: decor('Warranty').copyWith(
                    errorText: showErr && (int.tryParse(entry.durationCtrl.text) ?? 0) <= 0
                        ? 'Required'
                        : null,
                  ),
                  onChanged: (_) => onChanged(),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: Row(
                  children: [warrantyUnitMonths, warrantyUnitYears].map((u) {
                    final selected = entry.unit == u;
                    return Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(right: u == warrantyUnitMonths ? 6 : 0),
                        child: InkWell(
                          onTap: () {
                            entry.unit = u;
                            onChanged();
                          },
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            height: 42,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: selected ? AppColors.primary : (isDark ? AppColors.darkPageBg : AppColors.pageBg),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: selected ? AppColors.primary : borderColor),
                            ),
                            child: Text(
                              u == warrantyUnitMonths ? 'Months' : 'Years',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: selected ? Colors.white : AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
          if (expiry != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.event_available_outlined, size: 14, color: AppColors.textMuted),
                const SizedBox(width: 6),
                Text(
                  'Expires ${_dateFmt.format(expiry)}',
                  style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                ),
              ],
            ),
          ],
          const SizedBox(height: 8),
          TextField(
            controller: entry.notesCtrl,
            decoration: decor('Notes (optional)'),
            maxLines: 2,
          ),
          if (entry.costCtrl.text.isNotEmpty && double.tryParse(entry.costCtrl.text) != null) ...[
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                '₹${_moneyFmt.format(double.parse(entry.costCtrl.text))}',
                style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _RowTapField extends StatelessWidget {
  final String value;
  final IconData icon;
  final bool muted;
  final bool hasError;
  final VoidCallback onTap;

  const _RowTapField({
    required this.value,
    required this.icon,
    required this.onTap,
    this.muted = false,
    this.hasError = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final mutedColor = isDark ? AppColors.darkTextMuted : AppColors.textMuted;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        height: 42,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          border: Border.all(color: hasError ? AppColors.error : (isDark ? AppColors.darkBorder : AppColors.border)),
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
            Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: mutedColor),
          ],
        ),
      ),
    );
  }
}

/// Searchable picker with an inline "Add" action for options that don't
/// exist yet (used for part names).
class _SearchAddSheet extends StatefulWidget {
  final String title;
  final List<String> options;
  final String? selected;
  final Future<String> Function(String name) onAddNew;

  const _SearchAddSheet({
    required this.title,
    required this.options,
    required this.selected,
    required this.onAddNew,
  });

  @override
  State<_SearchAddSheet> createState() => _SearchAddSheetState();
}

class _SearchAddSheetState extends State<_SearchAddSheet> {
  String _query = '';
  bool _adding = false;

  List<String> get _filtered {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return widget.options;
    return widget.options.where((o) => o.toLowerCase().contains(q)).toList();
  }

  bool get _hasExactMatch =>
      widget.options.any((o) => o.toLowerCase() == _query.trim().toLowerCase());

  Future<void> _addNew() async {
    setState(() => _adding = true);
    try {
      final name = await widget.onAddNew(_query.trim());
      if (mounted) Navigator.pop(context, name);
    } catch (e) {
      if (mounted) {
        setState(() => _adding = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    final media = MediaQuery.of(context);
    final keyboardHeight = media.viewInsets.bottom;
    final maxListHeight = (media.size.height - keyboardHeight) * 0.42;
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                child: Text(
                  widget.title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: TextField(
                  autofocus: true,
                  style: TextStyle(color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary),
                  onChanged: (v) => setState(() => _query = v),
                  decoration: InputDecoration(
                    hintText: 'Search or type a new name',
                    prefixIcon: const Icon(Icons.search_rounded, size: 20),
                    isDense: true,
                    filled: true,
                    fillColor: isDark ? AppColors.darkPageBg : AppColors.pageBg,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.border),
                    ),
                  ),
                ),
              ),
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: maxListHeight.clamp(160.0, 420.0)),
                child: filtered.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Text(
                          'No matches',
                          style: TextStyle(
                            color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                          ),
                        ),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        itemCount: filtered.length,
                        itemBuilder: (_, i) {
                          final o = filtered[i];
                          final selected = widget.selected == o;
                          return ListTile(
                            dense: true,
                            title: Text(
                              o,
                              style: TextStyle(
                                fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                                color: selected
                                    ? AppColors.primary
                                    : (isDark ? AppColors.darkTextPrimary : AppColors.textPrimary),
                              ),
                            ),
                            trailing: selected ? const Icon(Icons.check_rounded, color: AppColors.primary) : null,
                            onTap: () => Navigator.pop(context, o),
                          );
                        },
                      ),
              ),
              if (_query.trim().isNotEmpty && !_hasExactMatch)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _adding ? null : _addNew,
                      icon: _adding
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(AppIcons.plus, size: 16),
                      label: Text('Add "${_query.trim()}"'),
                    ),
                  ),
                )
              else
                const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}

class _VendorPickerSheet extends StatefulWidget {
  final List<Vendor> vendors;
  final Vendor? selected;

  const _VendorPickerSheet({required this.vendors, this.selected});

  @override
  State<_VendorPickerSheet> createState() => _VendorPickerSheetState();
}

class _VendorPickerSheetState extends State<_VendorPickerSheet> {
  String _query = '';

  List<Vendor> get _filtered {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return widget.vendors;
    return widget.vendors
        .where((v) => [v.name, v.location].whereType<String>().join(' ').toLowerCase().contains(q))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    final media = MediaQuery.of(context);
    final keyboardHeight = media.viewInsets.bottom;
    final maxListHeight = (media.size.height - keyboardHeight) * 0.42;
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Select vendor',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: TextField(
                  autofocus: true,
                  style: TextStyle(color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary),
                  onChanged: (v) => setState(() => _query = v),
                  decoration: InputDecoration(
                    hintText: 'Search vendor name, location',
                    prefixIcon: const Icon(Icons.search_rounded, size: 20),
                    isDense: true,
                    filled: true,
                    fillColor: isDark ? AppColors.darkPageBg : AppColors.pageBg,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.border),
                    ),
                  ),
                ),
              ),
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: maxListHeight.clamp(160.0, 420.0)),
                child: filtered.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Text(
                          'No vendors found',
                          style: TextStyle(
                            color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                          ),
                        ),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        itemCount: filtered.length,
                        itemBuilder: (_, i) {
                          final v = filtered[i];
                          final selected = widget.selected?.id == v.id;
                          return ListTile(
                            dense: true,
                            title: Text(
                              v.name,
                              style: TextStyle(
                                fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                                color: selected
                                    ? AppColors.primary
                                    : (isDark ? AppColors.darkTextPrimary : AppColors.textPrimary),
                              ),
                            ),
                            subtitle: v.location != null
                                ? Text(
                                    v.location!,
                                    style: TextStyle(
                                      color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                                    ),
                                  )
                                : null,
                            trailing: selected ? const Icon(Icons.check_rounded, color: AppColors.primary) : null,
                            onTap: () => Navigator.pop(context, v),
                          );
                        },
                      ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}

String _trimZeros(double value) => value == value.roundToDouble() ? value.toInt().toString() : '$value';
