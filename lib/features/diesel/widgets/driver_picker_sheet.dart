import 'package:flutter/material.dart';
import 'package:mobile_sslogistics/core/constants/app_icons.dart';

import '../../../core/constants/app_colors.dart';
import '../../drivers/data/driver_models.dart';

/// Searchable driver picker used by the diesel create/edit sheets, mirroring
/// the web's driver typeahead (createDieselModal.tsx / editDieselModal.tsx)
/// including its "Add New Driver" nested action.
class DriverPickerSheet extends StatefulWidget {
  final List<Driver> drivers;
  final Driver? selectedDriver;
  final VoidCallback onAddNewDriver;

  const DriverPickerSheet({
    super.key,
    required this.drivers,
    this.selectedDriver,
    required this.onAddNewDriver,
  });

  @override
  State<DriverPickerSheet> createState() => _DriverPickerSheetState();
}

class _DriverPickerSheetState extends State<DriverPickerSheet> {
  String _query = '';

  List<Driver> get _filteredDrivers {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return widget.drivers;
    return widget.drivers.where((driver) {
      final haystack = [
        driver.name,
        driver.phone,
        driver.place,
      ].whereType<String>().join(' ').toLowerCase();
      return haystack.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredDrivers;
    final media = MediaQuery.of(context);
    final keyboardHeight = media.viewInsets.bottom;
    final maxListHeight = (media.size.height - keyboardHeight) * 0.42;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final secondaryColor =
        isDark ? AppColors.darkTextSecondary : AppColors.textSecondary;
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
                        'Select driver (${widget.drivers.length})',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: isDark
                              ? AppColors.darkTextPrimary
                              : AppColors.textPrimary,
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
                    hintText: 'Search driver name, phone',
                    prefixIcon: const Icon(Icons.search_rounded, size: 20),
                    isDense: true,
                    filled: true,
                    fillColor: isDark
                        ? AppColors.darkPageBg
                        : AppColors.pageBg,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
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
                      borderSide: const BorderSide(
                        color: AppColors.primary,
                        width: 1.4,
                      ),
                    ),
                  ),
                ),
              ),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: maxListHeight.clamp(160.0, 420.0),
                ),
                child: filtered.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 32),
                          child: Text(
                            'No drivers found',
                            style: TextStyle(color: secondaryColor),
                          ),
                        ),
                      )
                    : ListView.separated(
                        shrinkWrap: true,
                        itemCount: filtered.length,
                        separatorBuilder: (_, _) =>
                            Divider(height: 1, indent: 16, endIndent: 16, color: borderColor),
                        itemBuilder: (_, index) {
                          final driver = filtered[index];
                          final selected =
                              widget.selectedDriver?.id == driver.id;
                          return ListTile(
                            leading: Icon(AppIcons.user, color: secondaryColor),
                            title: Text(
                              driver.name,
                              style: TextStyle(
                                fontWeight: selected
                                    ? FontWeight.w800
                                    : FontWeight.w600,
                                color: selected
                                    ? AppColors.primary
                                    : (isDark
                                          ? AppColors.darkTextPrimary
                                          : AppColors.textPrimary),
                              ),
                            ),
                            subtitle:
                                [driver.phone, driver.place]
                                    .whereType<String>()
                                    .join(' · ')
                                    .isEmpty
                                ? null
                                : Text(
                                    [driver.phone, driver.place]
                                        .whereType<String>()
                                        .join(' · '),
                                  ),
                            trailing: selected
                                ? const Icon(
                                    Icons.check_rounded,
                                    color: AppColors.primary,
                                  )
                                : null,
                            onTap: () => Navigator.pop(context, driver),
                          );
                        },
                      ),
              ),
              const Divider(height: 1),
              InkWell(
                onTap: widget.onAddNewDriver,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.person_add_alt_1_rounded,
                        size: 18,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Add New Driver',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
