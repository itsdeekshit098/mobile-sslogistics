import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../../features/locations/data/location_models.dart';
import '../../features/locations/providers/location_provider.dart';

/// Drop-in replacement for a `TextFormField` on the trip-booking / external-
/// trip From/To fields: free text is still what gets submitted, this only
/// adds a live suggestion list underneath. Suggestions are looked up via
/// `/api/locations/autocomplete` once the field has 3+ characters; any
/// failure or empty result just means no suggestions — never an error and
/// never something that blocks typing or submission.
class LocationAutocompleteField extends ConsumerStatefulWidget {
  final TextEditingController controller;
  final Key? fieldKey;
  final FocusNode? focusNode;
  final InputDecoration decoration;
  final TextCapitalization textCapitalization;
  final String? Function(String?)? validator;

  const LocationAutocompleteField({
    super.key,
    required this.controller,
    required this.decoration,
    this.fieldKey,
    this.focusNode,
    this.textCapitalization = TextCapitalization.words,
    this.validator,
  });

  @override
  ConsumerState<LocationAutocompleteField> createState() =>
      _LocationAutocompleteFieldState();
}

class _LocationAutocompleteFieldState
    extends ConsumerState<LocationAutocompleteField> {
  static const _minQueryLength = 3;
  static const _debounce = Duration(milliseconds: 300);

  late final FocusNode _focusNode;
  late final bool _ownsFocusNode;
  Timer? _timer;
  int _requestId = 0;
  List<LocationSuggestion> _suggestions = [];
  bool _loading = false;
  bool _suppressNextLookup = false;

  @override
  void initState() {
    super.initState();
    _ownsFocusNode = widget.focusNode == null;
    _focusNode = widget.focusNode ?? FocusNode();
    _focusNode.addListener(_onFocusChange);
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _timer?.cancel();
    widget.controller.removeListener(_onTextChanged);
    _focusNode.removeListener(_onFocusChange);
    if (_ownsFocusNode) _focusNode.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (!_focusNode.hasFocus) {
      _timer?.cancel();
      setState(() {
        _suggestions = [];
        _loading = false;
      });
    }
  }

  void _onTextChanged() {
    if (_suppressNextLookup) {
      _suppressNextLookup = false;
      return;
    }
    _timer?.cancel();
    final query = widget.controller.text.trim();
    if (query.length < _minQueryLength) {
      if (_suggestions.isNotEmpty || _loading) {
        setState(() {
          _suggestions = [];
          _loading = false;
        });
      }
      return;
    }
    _timer = Timer(_debounce, () => _lookup(query));
  }

  Future<void> _lookup(String query) async {
    final requestId = ++_requestId;
    setState(() => _loading = true);
    final results =
        await ref.read(locationRepositoryProvider).autocomplete(query);
    if (!mounted || requestId != _requestId) return;
    setState(() {
      _suggestions = results;
      _loading = false;
    });
  }

  void _select(LocationSuggestion suggestion) {
    _suppressNextLookup = true;
    widget.controller.value = TextEditingValue(
      text: suggestion.label,
      selection: TextSelection.collapsed(offset: suggestion.label.length),
    );
    setState(() {
      _suggestions = [];
      _loading = false;
    });
    _focusNode.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextFormField(
          key: widget.fieldKey,
          controller: widget.controller,
          focusNode: _focusNode,
          decoration: widget.decoration,
          textCapitalization: widget.textCapitalization,
          validator: widget.validator,
        ),
        if (_loading || _suggestions.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 4),
            constraints: const BoxConstraints(maxHeight: 180),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCardBg : Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isDark ? AppColors.darkBorder : AppColors.border,
              ),
            ),
            child: _loading
                ? Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 13,
                          height: 13,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: isDark
                                ? AppColors.darkTextMuted
                                : AppColors.textMuted,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Searching...',
                          style: TextStyle(
                            fontSize: 12.5,
                            color: isDark
                                ? AppColors.darkTextMuted
                                : AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    padding: EdgeInsets.zero,
                    itemCount: _suggestions.length,
                    itemBuilder: (context, index) {
                      final suggestion = _suggestions[index];
                      return InkWell(
                        onTap: () => _select(suggestion),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          child: Text(
                            suggestion.label,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12.5,
                              color: isDark
                                  ? AppColors.darkTextPrimary
                                  : AppColors.textPrimary,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
      ],
    );
  }
}
