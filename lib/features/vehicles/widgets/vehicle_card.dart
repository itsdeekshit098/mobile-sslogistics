import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_icons.dart';
import '../data/vehicle_models.dart';

final _dateFmt = DateFormat('dd MMM yyyy');

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

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
      decoration: BoxDecoration(
        // Translucent rather than flat white — this is what actually makes
        // the card "glass": the BackdropFilter below blurs whatever is
        // behind it (the soft pastel blobs on the page), and this fill lets
        // that blur show through instead of hiding behind solid white.
        color: Colors.white.withValues(alpha: 0.58),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.75)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Material(
        color: Colors.transparent,
        child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Colored top accent tying each card back to the brand/glass
            // palette used in the hero above, instead of a flat white card
            // that has nothing visually in common with it.
            Container(
              height: 3,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [typeColor, typeColor.withValues(alpha: 0.25)],
                ),
              ),
            ),
            Padding(
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
                                    style: const TextStyle(
                                      fontSize: 18,
                                      height: 1.12,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    vehicle.vehicleType.isEmpty
                                        ? '-'
                                        : vehicleTypeLabel(vehicle.vehicleType),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: typeColor,
                                      fontWeight: FontWeight.w800,
                                    ),
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
                          ],
                        ),
                        const SizedBox(height: 11),
                        Wrap(
                          spacing: 7,
                          runSpacing: 7,
                          children: [
                            _InfoChip(
                              icon: _subDetailIcon(vehicle.vehicleType),
                              showIcon: _showSubDetailIcon(vehicle.vehicleType),
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
                Text(
                  'Last service: ${_formatDate(vehicle.lastServiceDate)}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
              if (onDocuments != null || canWrite || canDelete) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    if (onDocuments != null)
                      Expanded(child: _DocumentsButton(onTap: onDocuments)),
                    if (canWrite) ...[
                      if (onDocuments != null) const SizedBox(width: 10),
                      _IconActionButton(
                        icon: AppIcons.pencil,
                        color: AppColors.primary,
                        onTap: onEdit,
                      ),
                    ],
                    if (canDelete) ...[
                      if (onDocuments != null || canWrite)
                        const SizedBox(width: 10),
                      _IconActionButton(
                        icon: AppIcons.trash2,
                        color: AppColors.error,
                        onTap: onDelete,
                      ),
                    ],
                  ],
                ),
              ],
                ],
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
        return AppIcons.truck;
      default:
        return Icons.info_outline;
    }
  }

  static bool _showSubDetailIcon(String type) {
    switch (type.toUpperCase()) {
      case 'CAR':
      case 'BUS':
      case 'TEMPO_TRAVELLER':
        return true;
      default:
        return false;
    }
  }

  static Color _typeColor(String type) {
    switch (type.toUpperCase()) {
      case 'TRUCK':
        return AppColors.success;
      case 'CAR':
        return AppColors.tileDieselIcon;
      case 'BUS':
        return AppColors.tileClientsIcon;
      case 'TEMPO_TRAVELLER':
        return AppColors.primary;
      case 'CONTAINER':
        return AppColors.warning;
      default:
        return AppColors.textSecondary;
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
        color: Colors.white, // Pure white background as requested
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.2)),
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

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final bool showIcon;
  final String label;

  const _InfoChip({
    required this.icon,
    required this.showIcon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        // Translucent white rather than a flat pageBg patch, so it doesn't
        // read as an opaque block sitting inside the glass card around it.
        color: Colors.white.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.7)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.max,
        children: [
          if (showIcon) ...[
            Icon(icon, size: 14, color: AppColors.textMuted),
            const SizedBox(width: 5),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.fade,
              softWrap: true,
              style: const TextStyle(
                fontSize: 11.5,
                height: 1.12,
                color: AppColors.textSecondary,
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
  final VoidCallback? onTap;

  const _DocumentsButton({this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withValues(alpha: 0.7)),
        ),
        child: const Row(
          children: [
            Icon(AppIcons.fileText, size: 17, color: AppColors.textSecondary),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Documents',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Icon(AppIcons.chevronRight, size: 19, color: AppColors.textMuted),
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

  const _IconActionButton({
    required this.icon,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 46,
        height: 44,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
    );
  }
}
