import 'package:file_picker/file_picker.dart';
import 'package:file_saver/file_saver.dart';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_icons.dart';
import '../data/vehicle_models.dart';
import '../data/vehicle_repository.dart';
import '../../../shared/widgets/delete_confirmation_dialog.dart';

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
    final busy = _loadingKey != null;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return PopScope(
      canPop: !busy,
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkPageBg : AppColors.pageBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
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
                  color: isDark ? AppColors.darkBorder : AppColors.border,
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
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: isDark
                              ? AppColors.darkTextPrimary
                              : AppColors.textPrimary,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: busy ? null : () => Navigator.pop(context),
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
                      color: isDark ? AppColors.darkErrorBg : AppColors.errorBg,
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
                    final busy = _loadingKey != null;
                    final loading = _loadingKey?.split(':').last == doc.key;
                    return Card(
                      elevation: 0,
                      color: isDark ? AppColors.darkCardBg : Colors.white,
                      margin: const EdgeInsets.only(bottom: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: isDark
                              ? AppColors.darkBorder
                              : AppColors.border,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        doc.label,
                                        style: TextStyle(
                                          fontWeight: FontWeight.w800,
                                          color: isDark
                                              ? AppColors.darkTextPrimary
                                              : AppColors.textPrimary,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        path == null || path.isEmpty
                                            ? 'Not uploaded'
                                            : path.split('/').last,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: isDark
                                              ? AppColors.darkTextSecondary
                                              : AppColors.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (loading)
                                  const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                else ...[
                                  if (path != null && path.isNotEmpty)
                                    _ActionIcon(
                                      icon: Icons.visibility,
                                      color: isDark
                                          ? AppColors.darkTextSecondary
                                          : AppColors.textSecondary,
                                      enabled: !busy,
                                      onTap: () => _open(doc.key, path),
                                    ),
                                  if (path != null && path.isNotEmpty)
                                    _ActionIcon(
                                      icon: Icons.download,
                                      color: AppColors.primary,
                                      enabled: !busy,
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
                                      enabled: !busy,
                                      onTap: () => path == null || path.isEmpty
                                          ? _upload(doc.key)
                                          : _delete(doc.key, path),
                                    ),
                                ],
                              ],
                            ),
                            if (doc.dateFields != null) ...[
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Expanded(
                                    child: _DateField(
                                      label: 'Start Date',
                                      value: _vehicle.dateFieldValue(
                                        doc.dateFields!.startKey,
                                      ),
                                      // Validity dates are meaningless before
                                      // the document itself is uploaded.
                                      enabled:
                                          widget.canManage &&
                                          !busy &&
                                          path != null &&
                                          path.isNotEmpty,
                                      loading:
                                          _loadingKey ==
                                          'date:${doc.dateFields!.startKey}',
                                      onTap: () =>
                                          _pickDate(doc, isStart: true),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: _DateField(
                                      label: 'End Date',
                                      value: _vehicle.dateFieldValue(
                                        doc.dateFields!.endKey,
                                      ),
                                      enabled:
                                          widget.canManage &&
                                          !busy &&
                                          path != null &&
                                          path.isNotEmpty,
                                      loading:
                                          _loadingKey ==
                                          'date:${doc.dateFields!.endKey}',
                                      onTap: () =>
                                          _pickDate(doc, isStart: false),
                                    ),
                                  ),
                                ],
                              ),
                              if (path == null || path.isEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    'Upload the document to set validity dates.',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: isDark
                                          ? AppColors.darkTextSecondary
                                          : AppColors.textSecondary,
                                    ),
                                  ),
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
                      color: _isSuccess
                          ? AppColors.success
                          : AppColors.textPrimary,
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
                          const Icon(
                            AppIcons.checkCircle,
                            color: Colors.white,
                            size: 18,
                          ),
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
      ),
    );
  }

  /// Matches MAX_FILE_SIZE in the backend documents route — checked here so
  /// an oversized file fails fast instead of after a full upload.
  static const _maxUploadBytes = 10 * 1024 * 1024;

  Future<void> _upload(String key) async {
    if (_loadingKey != null) return;
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg', 'webp', 'xls', 'xlsx'],
    );
    final file = result?.files.single;
    final path = file?.path;
    if (file == null || path == null) return;
    if (file.size > _maxUploadBytes) {
      setState(() => _error = 'File exceeds maximum size of 10 MB');
      return;
    }
    await _run(
      'upload:$key',
      () async {
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
      },
      actionType: 'upload',
      successMessage: 'Document uploaded. Updating vehicle documents...',
    );
  }

  Future<void> _pickDate(
    VehicleDocumentType doc, {
    required bool isStart,
  }) async {
    if (_loadingKey != null) return;
    final docPath = _vehicle.documentPath(doc.key);
    if (docPath == null || docPath.isEmpty) return;
    final fields = doc.dateFields!;
    final key = isStart ? fields.startKey : fields.endKey;
    final currentValue = _vehicle.dateFieldValue(key);
    final initialDate = currentValue != null && currentValue.isNotEmpty
        ? DateTime.tryParse(currentValue) ?? DateTime.now()
        : DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    final isoDate = picked.toIso8601String().split('T').first;

    final startValue = isStart
        ? isoDate
        : _vehicle.dateFieldValue(fields.startKey);
    final endValue = isStart ? _vehicle.dateFieldValue(fields.endKey) : isoDate;
    if (startValue != null &&
        startValue.isNotEmpty &&
        endValue != null &&
        endValue.isNotEmpty &&
        DateTime.parse(endValue).isBefore(DateTime.parse(startValue))) {
      setState(() {
        _error = '${doc.label} end date must be on or after the start date';
      });
      return;
    }

    await _run(
      'date:$key',
      () => widget.repository.updateVehicleField(_vehicle.id, key, isoDate),
      actionType: 'date',
      successMessage: '${doc.label} date updated.',
      onSuccess: () {
        setState(() {
          _vehicle = _vehicle.copyWithDate(key, isoDate);
        });
      },
    );
  }

  Future<void> _delete(String key, String path) async {
    // Otherwise the user could confirm the dialog and have _run silently
    // drop the action because another one is still in flight.
    if (_loadingKey != null) return;
    final docLabel = vehicleDocumentTypes
        .firstWhere(
          (d) => d.key == key,
          orElse: () => VehicleDocumentType(key, key),
        )
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
      'delete:$key',
      () => widget.repository.deleteDocument(
        vehicleId: _vehicle.id,
        documentType: key,
        filePath: path,
      ),
      actionType: 'delete',
      successMessage: 'Document removed. Updating vehicle documents...',
      onSuccess: () {
        setState(() {
          _vehicle = _vehicle.copyWithDocument(key, null);
        });
      },
    );
  }

  Future<void> _open(String key, String path) async {
    await _run(
      'view:$key',
      () async {
        final localPath = await widget.repository.downloadDocument(path);
        final result = await OpenFilex.open(localPath);
        if (result.type != ResultType.done) {
          throw Exception(
            result.type == ResultType.noAppToOpen
                ? 'No app available to open this file type'
                : 'Could not open document: ${result.message}',
          );
        }
      },
      actionType: 'view',
      loadingMessage: 'Opening document...',
    );
  }

  Future<void> _download(String key, String path) async {
    await _run(
      'download:$key',
      () async {
        final fileName = _downloadFileName(key, path);
        final localPath = await widget.repository.downloadDocument(
          path,
          fileName: fileName,
        );
        final extension = fileName.split('.').last;
        final baseName = fileName.substring(
          0,
          fileName.length - extension.length - 1,
        );
        final mime = _mimeFor(extension);
        // Opens the native "Save As" dialog (Storage Access Framework on
        // Android, document picker on iOS) so the user can actually pick a
        // visible location like Downloads, instead of just opening a share sheet.
        final savedPath = await FileSaver.instance.saveAs(
          name: baseName,
          filePath: localPath,
          fileExtension: extension,
          mimeType: mime.mimeType,
          customMimeType: mime.customMimeType,
        );
        if (savedPath == null) {
          // User backed out of the save dialog — not an error.
          throw _ActionCancelled();
        }
      },
      actionType: 'download',
      loadingMessage: 'Downloading document...',
    );
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

  ({MimeType mimeType, String? customMimeType}) _mimeFor(String extension) {
    switch (extension.toLowerCase()) {
      case 'pdf':
        return (mimeType: MimeType.pdf, customMimeType: null);
      case 'png':
        return (mimeType: MimeType.png, customMimeType: null);
      case 'jpg':
      case 'jpeg':
        return (mimeType: MimeType.jpeg, customMimeType: null);
      case 'webp':
        return (mimeType: MimeType.webp, customMimeType: null);
      case 'xlsx':
        return (mimeType: MimeType.microsoftExcel, customMimeType: null);
      case 'xls':
        return (
          mimeType: MimeType.custom,
          customMimeType: 'application/vnd.ms-excel',
        );
      default:
        return (mimeType: MimeType.other, customMimeType: null);
    }
  }

  Future<void> _run(
    String loadingKey,
    Future<void> Function() action, {
    required String actionType,
    String? loadingMessage,
    String? successMessage,
    VoidCallback? onSuccess,
  }) async {
    if (_loadingKey != null) return; // another action is already in flight
    setState(() {
      _loadingKey = loadingKey;
      _error = null;
      _statusMessage = loadingMessage;
      _isSuccess = false;
    });
    try {
      await action();
      if (onSuccess != null && mounted) onSuccess();
      if (actionType != 'view') {
        final successText = actionType == 'download'
            ? 'Document downloaded successfully!'
            : (successMessage ?? 'Success!');
        if (mounted) {
          setState(() {
            _statusMessage = successText;
            _isSuccess = true;
          });
        }
        if (actionType != 'download') await widget.onChanged();

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
      if (e is _ActionCancelled) {
        if (mounted) {
          setState(() {
            _statusMessage = null;
          });
        }
      } else if (mounted) {
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

/// Thrown internally when the user backs out of the native save dialog.
/// Not a real error — `_run` swallows it without showing the error banner.
class _ActionCancelled implements Exception {}

class _DateField extends StatelessWidget {
  final String label;
  final String? value;
  final bool enabled;
  final bool loading;
  final VoidCallback onTap;

  const _DateField({
    required this.label,
    required this.value,
    required this.enabled,
    required this.onTap,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    // Dim the whole field while it (or a sibling action) is in flight, same
    // treatment _ActionIcon gets so busy state reads consistently row-to-row.
    final dimmed = !enabled || loading;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseBorder = isDark ? AppColors.darkBorder : AppColors.border;
    final baseMuted = isDark ? AppColors.darkTextMuted : AppColors.textMuted;
    final baseText = isDark
        ? AppColors.darkTextPrimary
        : AppColors.textPrimary;
    final borderColor = dimmed ? baseBorder.withValues(alpha: 0.5) : baseBorder;
    final mutedColor = dimmed ? baseMuted.withValues(alpha: 0.5) : baseMuted;
    final valueColor = value == null || value!.isEmpty
        ? mutedColor
        : (dimmed ? baseText.withValues(alpha: 0.5) : baseText);

    return InkWell(
      onTap: enabled && !loading ? onTap : null,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(color: borderColor),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            if (loading)
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 1.5),
              )
            else
              Icon(Icons.calendar_today, size: 14, color: mutedColor),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(fontSize: 10, color: mutedColor),
                  ),
                  Text(
                    value == null || value!.isEmpty ? 'Not set' : value!,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: valueColor,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionIcon extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final bool enabled;

  const _ActionIcon({
    required this.icon,
    required this.color,
    required this.onTap,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor = enabled ? color : color.withValues(alpha: 0.4);
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 36,
        height: 36,
        margin: const EdgeInsets.only(left: 8),
        decoration: BoxDecoration(
          color: effectiveColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: effectiveColor.withValues(alpha: 0.2)),
        ),
        child: Center(child: Icon(icon, color: effectiveColor, size: 18)),
      ),
    );
  }
}
