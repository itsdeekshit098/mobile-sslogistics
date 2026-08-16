import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../core/constants/api_constants.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_icons.dart';
import '../../core/network/dio_client.dart';
import '../models/api_response.dart';
import 'search_picker_sheet.dart';
import 'tap_field.dart';

/// One row of `lookup_options` — an editable dropdown entry.
class LookupOption {
  final int id;
  final String category;
  final String value;
  final String label;

  const LookupOption({
    required this.id,
    required this.category,
    required this.value,
    required this.label,
  });

  factory LookupOption.fromJson(Map<String, dynamic> json) => LookupOption(
        id: json['id'] as int,
        category: json['category'] as String? ?? '',
        value: json['value'] as String,
        label: json['label'] as String? ?? json['value'] as String,
      );

  @override
  bool operator ==(Object other) =>
      other is LookupOption && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// Picker over a runtime-editable list (`loan_type`, `client_type`,
/// `contact_role`, `payment_method`), with an inline "+ Add new".
///
/// The mobile counterpart of the web's `<LookupSelect>`. These lists live in
/// the `lookup_options` table precisely so a new loan type doesn't need a
/// release — that promise only holds if the phone can add one too, so the
/// create path is here rather than web-only.
class LookupSelectField extends StatefulWidget {
  /// `lookup_options.category`, e.g. `'loan_type'`.
  final String category;

  /// Currently selected `lookup_options.value`, or null.
  final String? value;

  final ValueChanged<String?> onChanged;

  /// Shown in the sheet title and the add-new row: "loan type" →
  /// "Select loan type" / "Add new loan type".
  final String noun;

  final String placeholder;
  final bool enabled;
  final bool hasError;

  /// Allows clearing the selection.
  final bool clearable;

  const LookupSelectField({
    super.key,
    required this.category,
    required this.value,
    required this.onChanged,
    required this.noun,
    this.placeholder = 'Select',
    this.enabled = true,
    this.hasError = false,
    this.clearable = false,
  });

  @override
  State<LookupSelectField> createState() => _LookupSelectFieldState();
}

class _LookupSelectFieldState extends State<LookupSelectField> {
  Dio get _dio => DioClient.dio;

  List<LookupOption> _options = const [];
  bool _loading = true;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final response = await _dio.get(
        ApiConstants.lookups,
        queryParameters: {'category': widget.category},
      );
      final data = unwrapResponse<Map<String, dynamic>>(
        response,
        fallbackError: 'Failed to load options',
      );
      final list = (data['data'] as List<dynamic>? ?? [])
          .map((e) => LookupOption.fromJson(e as Map<String, dynamic>))
          .toList();
      if (!mounted) return;
      setState(() {
        _options = list;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  LookupOption? get _selected {
    for (final option in _options) {
      if (option.value == widget.value) return option;
    }
    return null;
  }

  Future<void> _openPicker() async {
    final result = await showSearchPicker<LookupOption>(
      context,
      title: 'Select ${widget.noun}',
      icon: AppIcons.fileText,
      items: _options,
      selected: _selected,
      searchHint: 'Search ${widget.noun}...',
      labelBuilder: (o) => o.label,
      subtitleBuilder: (_) => '',
      matcher: (o, q) =>
          o.label.toLowerCase().contains(q) || o.value.toLowerCase().contains(q),
      clearLabel: widget.clearable ? 'Clear selection' : null,
      addNewLabel: 'Add new ${widget.noun}',
      onAddNew: _openAddNew,
      isLoading: _loading,
    );

    if (!mounted || result == null) return;
    if (result is ClearPick) {
      widget.onChanged(null);
    } else if (result is LookupOption) {
      widget.onChanged(result.value);
    }
  }

  Future<void> _openAddNew() async {
    final created = await showModalBottomSheet<LookupOption>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddLookupOptionSheet(
        category: widget.category,
        noun: widget.noun,
      ),
    );

    if (!mounted || created == null) return;
    // Select it immediately — the user only created it to use it here.
    setState(() => _options = [..._options, created]);
    widget.onChanged(created.value);
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selected;
    final label = _loading && widget.value == null
        ? 'Loading…'
        : (selected?.label ?? widget.value ?? widget.placeholder);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TapField(
          value: label,
          icon: AppIcons.fileText,
          muted: selected == null && widget.value == null,
          hasError: widget.hasError,
          enabled: widget.enabled,
          onTap: _openPicker,
          onClear: widget.clearable && widget.value != null
              ? () => widget.onChanged(null)
              : null,
        ),
        if (_loadError != null)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 2),
            child: GestureDetector(
              onTap: _load,
              child: Text(
                "$_loadError — tap to retry",
                style: const TextStyle(fontSize: 11.5, color: AppColors.error),
              ),
            ),
          ),
      ],
    );
  }
}

/// Creates a `lookup_options` row without leaving the form that needed it.
class _AddLookupOptionSheet extends StatefulWidget {
  final String category;
  final String noun;

  const _AddLookupOptionSheet({required this.category, required this.noun});

  @override
  State<_AddLookupOptionSheet> createState() => _AddLookupOptionSheetState();
}

class _AddLookupOptionSheetState extends State<_AddLookupOptionSheet> {
  final _controller = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final label = _controller.text.trim();
    if (label.isEmpty) {
      setState(() => _error = 'Enter a name');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final response = await DioClient.dio.post(
        ApiConstants.lookups,
        // `value` is derived server-side from the label when omitted, so the
        // phone never invents a code that the web would render differently.
        data: {'category': widget.category, 'label': label},
      );
      final data = unwrapResponse<Map<String, dynamic>>(
        response,
        fallbackError: 'Failed to add',
      );
      final created = LookupOption.fromJson(data['option'] as Map<String, dynamic>);
      if (mounted) Navigator.pop(context, created);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.border;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Material(
        color: isDark ? AppColors.darkCardBg : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
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
                const SizedBox(height: 16),
                Text(
                  'New ${widget.noun}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _controller,
                  autofocus: true,
                  textCapitalization: TextCapitalization.words,
                  onSubmitted: (_) => _submit(),
                  decoration: InputDecoration(
                    hintText: 'e.g. Machinery Loan',
                    errorText: _error,
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _submitting ? null : _submit,
                  child: _submitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Add'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
