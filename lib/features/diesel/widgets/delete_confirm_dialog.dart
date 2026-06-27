import 'package:flutter/material.dart';
import 'package:mobile_sslogistics/core/constants/app_icons.dart';
import '../../../core/constants/app_colors.dart';

class DeleteConfirmDialog extends StatelessWidget {
  final String vehiclePlate;
  final String date;
  final String driverName;
  final double fuelLitres;
  final VoidCallback onConfirm;

  const DeleteConfirmDialog({
    super.key,
    required this.vehiclePlate,
    required this.date,
    required this.driverName,
    required this.fuelLitres,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      icon: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: AppColors.errorBg,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(
          AppIcons.trash2,
          color: AppColors.error,
          size: 22,
        ),
      ),
      title: const Text(
        'Delete Record',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.pageBg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _DetailRow(label: 'Date', value: date),
                _DetailRow(label: 'Vehicle', value: vehiclePlate),
                _DetailRow(label: 'Driver', value: driverName),
                _DetailRow(
                    label: 'Fuel',
                    value: '${fuelLitres.toStringAsFixed(1)} L'),
              ],
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'This action cannot be undone.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
            ),
          ),
        ],
      ),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        OutlinedButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        const SizedBox(width: 8),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.error,
            foregroundColor: Colors.white,
          ),
          onPressed: () {
            Navigator.pop(context);
            onConfirm();
          },
          child: const Text('Delete'),
        ),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 52,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textMuted,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
