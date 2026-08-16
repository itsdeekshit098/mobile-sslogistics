import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_icons.dart';

/// Sentinel popped when the user taps the "clear" row, so a caller can tell
/// "cleared the selection" apart from "dismissed without choosing" (which pops
/// null).
class ClearPick {
  const ClearPick();
}

/// Searchable picker bottom sheet.
///
/// Promoted from the private `_SearchPickerSheet` that was copy-pasted into
/// `trip_booking_form_sheet.dart` and `warranty_form_sheet.dart` — the finance
/// forms need it six more times, and a sixth copy of 160 lines is how the
/// versions drift apart.
///
/// Adds one thing the private copies didn't have: [onAddNew], the mobile
/// equivalent of the web `Typeahead`'s "+ Add new" footer. It lets a lender,
/// entity or lookup option be created without abandoning the form that needed
/// it.
///
/// Pops the chosen item, a [ClearPick], or null.
class SearchPickerSheet<T> extends StatefulWidget {
  final String title;
  final IconData icon;
  final List<T> items;
  final T? selected;
  final String searchHint;
  final String Function(T item) labelBuilder;
  final String Function(T item) subtitleBuilder;
  final bool Function(T item, String query) matcher;

  /// Shows a "clear selection" row at the top when non-null.
  final String? clearLabel;

  /// Label for the create-new action pinned under the list, e.g. "Add new
  /// lender". Nothing is rendered when null.
  final String? addNewLabel;

  /// Called when the create-new action is tapped. The sheet closes first, so
  /// the caller can open its own sheet without stacking two on top of each
  /// other; a newly created item is selected by the caller.
  final VoidCallback? onAddNew;

  /// Shown instead of "No results found" while the list is still loading — an
  /// empty list and a list that hasn't arrived look identical otherwise.
  final bool isLoading;

  const SearchPickerSheet({
    super.key,
    required this.title,
    required this.icon,
    required this.items,
    required this.selected,
    required this.searchHint,
    required this.labelBuilder,
    required this.subtitleBuilder,
    required this.matcher,
    this.clearLabel,
    this.addNewLabel,
    this.onAddNew,
    this.isLoading = false,
  });

  @override
  State<SearchPickerSheet<T>> createState() => _SearchPickerSheetState<T>();
}

class _SearchPickerSheetState<T> extends State<SearchPickerSheet<T>> {
  String _query = '';

  List<T> get _filtered {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return widget.items;
    return widget.items.where((item) => widget.matcher(item, q)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    final media = MediaQuery.of(context);
    final keyboardHeight = media.viewInsets.bottom;
    final maxListHeight = (media.size.height - keyboardHeight) * 0.42;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final secondaryColor = isDark ? AppColors.darkTextSecondary : AppColors.textSecondary;
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
                decoration: BoxDecoration(
                  color: borderColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 8, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(AppIcons.x, size: 20),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                child: TextField(
                  autofocus: true,
                  onChanged: (value) => setState(() => _query = value),
                  decoration: InputDecoration(
                    hintText: widget.searchHint,
                    prefixIcon: const Icon(Icons.search_rounded, size: 20),
                    isDense: true,
                    filled: true,
                    fillColor: isDark ? AppColors.darkPageBg : AppColors.pageBg,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: borderColor),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: borderColor),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.primary, width: 1.4),
                    ),
                  ),
                ),
              ),
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: maxListHeight.clamp(160.0, 420.0)),
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    if (widget.clearLabel != null)
                      ListTile(
                        leading: Icon(AppIcons.x, color: secondaryColor),
                        title: Text(widget.clearLabel!, style: TextStyle(color: secondaryColor)),
                        onTap: () => Navigator.pop(context, const ClearPick()),
                      ),
                    if (widget.isLoading)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 32),
                        child: Center(
                          child: SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2.5),
                          ),
                        ),
                      )
                    else if (filtered.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 32),
                        child: Center(
                          child: Text('No results found', style: TextStyle(color: secondaryColor)),
                        ),
                      )
                    else
                      ...filtered.map((item) {
                        final selected = widget.selected == item;
                        final subtitle = widget.subtitleBuilder(item);
                        return ListTile(
                          leading: Icon(widget.icon, color: secondaryColor),
                          title: Text(
                            widget.labelBuilder(item),
                            style: TextStyle(
                              fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                              color: selected
                                  ? AppColors.primary
                                  : (isDark
                                      ? AppColors.darkTextPrimary
                                      : AppColors.textPrimary),
                            ),
                          ),
                          subtitle: subtitle.isEmpty ? null : Text(subtitle),
                          trailing: selected
                              ? const Icon(Icons.check_rounded, color: AppColors.primary)
                              : null,
                          onTap: () => Navigator.pop(context, item),
                        );
                      }),
                  ],
                ),
              ),
              if (widget.addNewLabel != null && widget.onAddNew != null) ...[
                Divider(height: 1, color: borderColor),
                ListTile(
                  leading: const Icon(AppIcons.plus, color: AppColors.primary),
                  title: Text(
                    widget.addNewLabel!,
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  onTap: () {
                    // Close first so the caller's create sheet isn't stacked on
                    // top of this one.
                    Navigator.pop(context);
                    widget.onAddNew!();
                  },
                ),
              ],
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}

/// Opens a [SearchPickerSheet] with this app's standard modal arguments and
/// resolves to the chosen item, [ClearPick], or null.
Future<Object?> showSearchPicker<T>(
  BuildContext context, {
  required String title,
  required IconData icon,
  required List<T> items,
  required T? selected,
  required String searchHint,
  required String Function(T item) labelBuilder,
  required String Function(T item) subtitleBuilder,
  required bool Function(T item, String query) matcher,
  String? clearLabel,
  String? addNewLabel,
  VoidCallback? onAddNew,
  bool isLoading = false,
}) {
  return showModalBottomSheet<Object?>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => SearchPickerSheet<T>(
      title: title,
      icon: icon,
      items: items,
      selected: selected,
      searchHint: searchHint,
      labelBuilder: labelBuilder,
      subtitleBuilder: subtitleBuilder,
      matcher: matcher,
      clearLabel: clearLabel,
      addNewLabel: addNewLabel,
      onAddNew: onAddNew,
      isLoading: isLoading,
    ),
  );
}
