import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_icons.dart';
import '../data/vehicle_models.dart';

final _dateFmt = DateFormat('dd MMM yyyy');

({String message, Color color})? _documentWarning(FleetVehicle vehicle) {
  final fc = vehicle.fcStatus;
  final ins = vehicle.insuranceStatus;
  final fcBad = fc == 'expired' || fc == 'expiring_soon';
  final insBad = ins == 'expired' || ins == 'expiring_soon';
  if (!fcBad && !insBad) return null;

  final color = (fc == 'expired' || ins == 'expired')
      ? AppColors.error
      : AppColors.warning;

  String phrase(String label, String status) =>
      status == 'expired' ? '$label is expired' : '$label is expiring soon';

  final String message;
  if (fcBad && insBad) {
    message = fc == ins
        ? (fc == 'expired'
            ? 'FC and insurance are expired'
            : 'FC and insurance are expiring soon')
        : '${phrase('FC', fc!)}, ${phrase('insurance', ins!).toLowerCase()}';
  } else if (fcBad) {
    message = phrase('FC', fc!);
  } else {
    message = phrase('Insurance', ins!);
  }
  return (message: message, color: color);
}

class VehicleCard extends StatelessWidget {
  final FleetVehicle vehicle;
  final bool canWrite;
  final bool canDelete;
  final VoidCallback onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onDocuments;

  const VehicleCard({
    super.key,
    required this.vehicle,
    required this.canWrite,
    required this.canDelete,
    required this.onTap,
    this.onEdit,
    this.onDelete,
    this.onDocuments,
  });

  @override
  Widget build(BuildContext context) {
    final typeColor = _typeColor(vehicle.vehicleType);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCardBg : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.border,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
        onTap: onTap,
        child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Colored left accent tying each card back to the brand/glass
            // palette used in the hero above, instead of a flat white card
            // that has nothing visually in common with it.
            Container(
              width: 4,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [typeColor, typeColor.withValues(alpha: 0.25)],
                ),
              ),
            ),
            Expanded(
              child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _VehicleVisual(vehicle: vehicle, color: typeColor),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    vehicle.vehicleNumber,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 18,
                                      height: 1.12,
                                      fontWeight: FontWeight.w800,
                                      color: isDark
                                          ? AppColors.darkTextPrimary
                                          : AppColors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  _TypePill(
                                    label: vehicle.vehicleType.isEmpty
                                        ? '-'
                                        : vehicleTypeLabel(vehicle.vehicleType),
                                    color: typeColor,
                                  ),
                                ],
                              ),
                            ),
                            if (vehicle.ownerType == 'EXTERNAL') ...[
                              const SizedBox(width: 8),
                              const _StatusBadge(
                                label: 'External',
                                color: AppColors.warning,
                              ),
                            ],
                            if (canWrite) ...[
                              const SizedBox(width: 8),
                              _IconActionButton(
                                icon: AppIcons.pencil,
                                color: AppColors.primary,
                                onTap: onEdit,
                                compact: true,
                              ),
                            ],
                            if (canDelete) ...[
                              const SizedBox(width: 8),
                              _IconActionButton(
                                icon: AppIcons.trash2,
                                color: AppColors.error,
                                onTap: onDelete,
                                compact: true,
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 11),
                        Wrap(
                          spacing: 7,
                          runSpacing: 7,
                          children: [
                            _InfoChip(
                              icon: _subDetailIcon(vehicle.vehicleType),
                              color: typeColor,
                              label: vehicleSubDetail(vehicle),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (vehicle.lastServiceDate != null &&
                  vehicle.lastServiceDate!.isNotEmpty) ...[
                const SizedBox(height: 9),
                Row(
                  children: [
                    Icon(
                      AppIcons.clock,
                      size: 13,
                      color: isDark
                          ? AppColors.darkTextMuted
                          : AppColors.textMuted,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'Last service: ${_formatDate(vehicle.lastServiceDate)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark
                            ? AppColors.darkTextMuted
                            : AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ],
              if (onDocuments != null) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: _DocumentsButton(
                    color: typeColor,
                    onTap: onDocuments,
                    warning: _documentWarning(vehicle),
                  ),
                ),
              ],
                ],
              ),
              ),
            ),
          ],
        ),
        ),
      ),
      ),
    );
  }

  static String _formatDate(String? value) {
    final parsed = value == null ? null : DateTime.tryParse(value)?.toLocal();
    return parsed == null ? '-' : _dateFmt.format(parsed);
  }

  static IconData _subDetailIcon(String type) {
    switch (type.toUpperCase()) {
      case 'CAR':
      case 'BUS':
      case 'TEMPO_TRAVELLER':
        return Icons.airline_seat_recline_normal;
      case 'TRUCK':
        return AppIcons.truck;
      case 'CONTAINER':
        return Icons.inventory_2_outlined;
      default:
        return Icons.info_outline;
    }
  }

  static Color _typeColor(String type) {
    switch (type.toUpperCase()) {
      case 'TRUCK':
        return AppColors.tileDieselIcon;
      case 'CAR':
        return AppColors.tileDieselIcon;
      case 'BUS':
        return AppColors.tileClientsIcon;
      case 'TEMPO_TRAVELLER':
        return AppColors.primary;
      case 'CONTAINER':
        return AppColors.tileDieselIcon;
      default:
        return AppColors.textMuted;
    }
  }
}

class _VehicleVisual extends StatelessWidget {
  final FleetVehicle vehicle;
  final Color color;

  const _VehicleVisual({required this.vehicle, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 96,
      height: 96,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: vehicle.logoUrl?.isNotEmpty == true
            ? Image.network(
                vehicle.logoUrl!,
                fit: BoxFit.contain, // Fit perfectly without cropping
                errorBuilder: (context, error, stackTrace) =>
                    _VehicleFallback(type: vehicle.vehicleType, color: color),
              )
            : _VehicleFallback(type: vehicle.vehicleType, color: color),
      ),
    );
  }
}

class _VehicleFallback extends StatelessWidget {
  final String type;
  final Color color;

  const _VehicleFallback({required this.type, required this.color});

  @override
  Widget build(BuildContext context) {
    final assetPath = _assetForType(type);

    if (assetPath != null) {
      return Image.asset(
        assetPath,
        fit: BoxFit.contain, // Fit perfectly without cropping
        errorBuilder: (context, error, stackTrace) => _buildIconFallback(),
      );
    }
    return _buildIconFallback();
  }

  Widget _buildIconFallback() {
    return Center(child: Icon(_iconForType(type), color: color, size: 42));
  }

  String? _assetForType(String type) {
    switch (type.toUpperCase()) {
      case 'CAR':
        return 'assets/images/car.png';
      case 'BUS':
        return 'assets/images/bus.png';
      case 'TEMPO_TRAVELLER':
        return 'assets/images/tempoTraveller.png';
      case 'TRUCK':
        return 'assets/images/truck.png';
      case 'CONTAINER':
        return 'assets/images/truck.png';
      default:
        return null;
    }
  }

  IconData _iconForType(String type) {
    switch (type.toUpperCase()) {
      case 'CAR':
        return Icons.directions_car_filled;
      case 'BUS':
        return Icons.directions_bus_filled;
      case 'TEMPO_TRAVELLER':
        return Icons.airport_shuttle;
      case 'CONTAINER':
        return Icons.inventory_2_outlined;
      case 'TRUCK':
        return AppIcons.truck;
      default:
        return AppIcons.truck;
    }
  }
}

class _StatusBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.24)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }
}

class _TypePill extends StatelessWidget {
  final String label;
  final Color color;

  const _TypePill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: color),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;

  const _InfoChip({
    required this.icon,
    required this.color,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkPageBg : AppColors.pageBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.border,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.max,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.fade,
              softWrap: true,
              style: TextStyle(
                fontSize: 11.5,
                height: 1.12,
                color: isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.textSecondary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DocumentsButton extends StatelessWidget {
  final Color color;
  final VoidCallback? onTap;
  final ({String message, Color color})? warning;

  const _DocumentsButton({required this.color, this.onTap, this.warning});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final warning = this.warning;
    final neutralTextColor =
        isDark ? AppColors.darkTextSecondary : AppColors.textSecondary;
    final contentColor = warning?.color ?? neutralTextColor;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: warning != null
              ? warning.color.withValues(alpha: 0.1)
              : (isDark ? AppColors.darkCardBg : Colors.white),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: warning != null
                ? warning.color.withValues(alpha: 0.3)
                : (isDark ? AppColors.darkBorder : AppColors.border),
          ),
        ),
        child: Row(
          children: [
            Icon(
              AppIcons.fileText,
              size: warning != null ? 30 : 18,
              color: contentColor,
            ),
            SizedBox(width: warning != null ? 10 : 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Documents',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      color: contentColor,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (warning != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      warning.message,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: warning.color,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Icon(
              AppIcons.chevronRight,
              size: 19,
              color: isDark ? AppColors.darkTextMuted : AppColors.textMuted,
            ),
          ],
        ),
      ),
    );
  }
}

class _IconActionButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;
  final bool compact;

  const _IconActionButton({
    required this.icon,
    required this.color,
    this.onTap,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final size = compact ? 32.0 : 44.0;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(compact ? 9 : 12),
      child: Container(
        width: compact ? size : 46,
        height: size,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(compact ? 9 : 12),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Icon(icon, color: color, size: compact ? 16 : 20),
      ),
    );
  }
}
