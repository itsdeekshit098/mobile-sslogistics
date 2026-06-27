import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_icons.dart';
import '../data/vehicle_models.dart';
import '../data/vehicle_repository.dart';
import 'delete_confirmation_dialog.dart';

class VehicleDocumentsSheet extends StatefulWidget {
  final FleetVehicle vehicle;
  final VehicleRepository repository;
  final Future<void> Function() onChanged;
  final bool canManage;

  const VehicleDocumentsSheet({
    super.key,
    required this.vehicle,
    required this.repository,
    required this.onChanged,
    required this.canManage,
  });

  @override
  State<VehicleDocumentsSheet> createState() => _VehicleDocumentsSheetState();
}

class _VehicleDocumentsSheetState extends State<VehicleDocumentsSheet> {
  late FleetVehicle _vehicle;
  String? _loadingKey;
  String? _error;
  String? _statusMessage;
  bool _isSuccess = false;

  @override
  void initState() {
    super.initState();
    _vehicle = widget.vehicle;
  }

  @override
  void didUpdateWidget(covariant VehicleDocumentsSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.vehicle != widget.vehicle) {
      _vehicle = widget.vehicle;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.pageBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 12, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Documents - ${_vehicle.vehicleNumber}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(AppIcons.x),
                  ),
                ],
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.errorBg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: AppColors.error),
                  ),
                ),
              ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                itemCount: vehicleDocumentTypes.length,
                itemBuilder: (context, index) {
                  final doc = vehicleDocumentTypes[index];
                  final path = _vehicle.documentPath(doc.key);
                  final loading = _loadingKey == doc.key;
                  return Card(
                    elevation: 0,
                    color: Colors.white,
                    margin: const EdgeInsets.only(bottom: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: const BorderSide(color: AppColors.border),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: AppColors.tileVehiclesBg,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              AppIcons.fileText,
                              color: AppColors.primary,
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  doc.label,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  path == null || path.isEmpty
                                      ? 'Not uploaded'
                                      : path.split('/').last,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (loading)
                            const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          else ...[
                            if (path != null && path.isNotEmpty)
                              _ActionIcon(
                                icon: Icons.visibility,
                                color: AppColors.textSecondary,
                                onTap: () => _open(path),
                              ),
                            if (path != null && path.isNotEmpty)
                              _ActionIcon(
                                icon: Icons.download,
                                color: AppColors.primary,
                                onTap: () => _download(doc.key, path),
                              ),
                            if (widget.canManage)
                              _ActionIcon(
                                icon: path == null || path.isEmpty
                                    ? Icons.upload_file
                                    : Icons.delete,
                                color: path == null || path.isEmpty
                                    ? AppColors.primary
                                    : AppColors.error,
                                onTap: () => path == null || path.isEmpty
                                    ? _upload(doc.key)
                                    : _delete(doc.key, path),
                              ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            if (_statusMessage != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: _isSuccess ? AppColors.success : AppColors.textPrimary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      if (!_isSuccess)
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      else
                        const Icon(AppIcons.checkCircle, color: Colors.white, size: 18),
                      SizedBox(width: _isSuccess ? 8 : 10),
                      Expanded(
                        child: Text(
                          _statusMessage!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _upload(String key) async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg', 'webp', 'xls', 'xlsx'],
    );
    final path = result?.files.single.path;
    if (path == null) return;
    await _run(key, () async {
      final uploadedPath = await widget.repository.uploadDocument(
        vehicle: _vehicle,
        documentType: key,
        filePath: path,
      );
      if (mounted) {
        setState(() {
          _vehicle = _vehicle.copyWithDocument(key, uploadedPath);
        });
      }
    }, successMessage: 'Document uploaded. Updating vehicle documents...');
  }

  Future<void> _delete(String key, String path) async {
    final docLabel = vehicleDocumentTypes
        .firstWhere((d) => d.key == key, orElse: () => VehicleDocumentType(key, key))
        .label;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => DeleteConfirmationDialog(
        title: 'Delete Document',
        targetName: '$docLabel - ${_vehicle.vehicleNumber.toUpperCase()}',
        warningText: 'This action cannot be undone.',
        warningSubtext: 'This document will be permanently removed.',
        confirmLabel: 'Delete',
      ),
    );
    if (confirmed != true) return;
    await _run(
      key,
      () => widget.repository.deleteDocument(
        vehicleId: _vehicle.id,
        documentType: key,
        filePath: path,
      ),
      successMessage: 'Document removed. Updating vehicle documents...',
      onSuccess: () {
        setState(() {
          _vehicle = _vehicle.copyWithDocument(key, null);
        });
      },
    );
  }

  Future<void> _open(String path) async {
    await _run('view', () async {
      final localPath = await widget.repository.downloadDocument(path);
      await OpenFilex.open(localPath);
    }, loadingMessage: 'Opening document...');
  }

  Future<void> _download(String key, String path) async {
    await _run('download', () async {
      await widget.repository.downloadDocument(
        path,
        fileName: _downloadFileName(key, path),
      );
    }, loadingMessage: 'Downloading document...');
  }

  String _downloadFileName(String key, String path) {
    final extension = path.split('/').last.split('.').last;
    final documentType = key.replaceFirst(RegExp(r'_url$'), '');
    final vehicleNumber = _vehicle.vehicleNumber
        .trim()
        .replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '')
        .toUpperCase();
    return '${documentType}_$vehicleNumber.$extension';
  }

  Future<void> _run(
    String key,
    Future<void> Function() action, {
    String? loadingMessage,
    String? successMessage,
    VoidCallback? onSuccess,
  }) async {
    setState(() {
      _loadingKey = key;
      _error = null;
      _statusMessage = loadingMessage;
      _isSuccess = false;
    });
    try {
      await action();
      if (onSuccess != null && mounted) onSuccess();
      if (key != 'view') {
        final successText = key == 'download' ? 'Document downloaded successfully!' : (successMessage ?? 'Success!');
        if (mounted) {
          setState(() {
            _statusMessage = successText;
            _isSuccess = true;
          });
        }
        if (key != 'download') await widget.onChanged();
        
        // Hide success message after 2.5 seconds
        Future.delayed(const Duration(milliseconds: 2500), () {
          if (mounted && _statusMessage == successText) {
            setState(() => _statusMessage = null);
          }
        });
      } else {
        if (mounted) {
          setState(() {
            _statusMessage = null;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceFirst('Exception: ', '');
          _statusMessage = null; // Clear status on error
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _loadingKey = null;
          // DO NOT clear _statusMessage here because it might be displaying the success message!
        });
      }
    }
  }
}

class _ActionIcon extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ActionIcon({
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 36,
        height: 36,
        margin: const EdgeInsets.only(left: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Center(
          child: Icon(icon, color: color, size: 18),
        ),
      ),
    );
  }
}
