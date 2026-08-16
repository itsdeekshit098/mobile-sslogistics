import 'package:cached_network_image/cached_network_image.dart';
import 'package:file_picker/file_picker.dart';
import 'package:file_saver/file_saver.dart';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';

import '../../core/constants/api_constants.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_icons.dart';
import '../../core/network/dio_client.dart';
import '../data/attachment_models.dart';
import '../data/attachment_repository.dart';
import 'delete_confirmation_dialog.dart';

/// One bottom sheet for both many-files features — a vehicle's photo gallery
/// and a client ledger entry's payment proofs. They share a bucket and a pair
/// of API routes (see sql/38_add_attachments.sql); this widget is the one UI
/// on top of both, split only by [ownerType]/[ownerId] and [allowPdf].
///
/// Modelled closely on `VehicleDocumentsSheet`: the single `_loadingKey`
/// gate, `PopScope(canPop: !busy)`, the auto-hiding status banner, and the
/// download-to-temp-then-open/save-as flow for View and Download.
class AttachmentsSheet extends StatefulWidget {
  final AttachmentOwnerType ownerType;
  final int ownerId;
  final String title;
  final bool canManage;
  final bool allowPdf;

  const AttachmentsSheet({
    super.key,
    required this.ownerType,
    required this.ownerId,
    required this.title,
    required this.canManage,
    this.allowPdf = false,
  });

  @override
  State<AttachmentsSheet> createState() => _AttachmentsSheetState();
}

class _AttachmentsSheetState extends State<AttachmentsSheet> {
  final _repository = AttachmentRepository();

  List<Attachment> _attachments = [];
  bool _loading = true;
  String? _loadingKey;
  String? _error;
  String? _statusMessage;
  bool _isSuccess = false;
  String? _cookieHeader;
  bool _selectionMode = false;
  Set<int> _selectedIds = {};

  @override
  void initState() {
    super.initState();
    _load();
    _loadCookieHeader();
  }

  Future<void> _loadCookieHeader() async {
    final header = await DioClient.cookieHeaderFor(
      Uri.parse(ApiConstants.baseUrl),
    );
    if (mounted) setState(() => _cookieHeader = header);
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final attachments = await _repository.fetchFor(
        ownerType: widget.ownerType,
        ownerId: widget.ownerId,
      );
      if (mounted) setState(() => _attachments = attachments);
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
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
                        widget.title,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: isDark
                              ? AppColors.darkTextPrimary
                              : AppColors.textPrimary,
                        ),
                      ),
                    ),
                    if (!_loading && _attachments.isNotEmpty)
                      TextButton(
                        onPressed: busy ? null : _toggleSelectionMode,
                        child: Text(_selectionMode ? 'Cancel' : 'Select'),
                      ),
                    IconButton(
                      onPressed: busy ? null : () => Navigator.pop(context),
                      icon: const Icon(AppIcons.x),
                    ),
                  ],
                ),
              ),
              if (widget.canManage && !_selectionMode)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: busy ? null : _upload,
                      icon: const Icon(AppIcons.uploadCloud, size: 18),
                      label: const Text('Upload'),
                    ),
                  ),
                ),
              if (_selectionMode)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${_selectedIds.length} selected',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: isDark
                                ? AppColors.darkTextSecondary
                                : AppColors.textSecondary,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: busy ? null : _toggleSelectAll,
                        child: Text(
                          _selectedIds.length == _attachments.length
                              ? 'Deselect all'
                              : 'Select all',
                        ),
                      ),
                      const SizedBox(width: 4),
                      ElevatedButton.icon(
                        onPressed: (busy || _selectedIds.isEmpty)
                            ? null
                            : _downloadSelected,
                        icon: const Icon(Icons.download, size: 18),
                        label: const Text('Download'),
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
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _attachments.isEmpty
                    ? Center(
                        child: Text(
                          widget.canManage
                              ? 'Nothing uploaded yet.'
                              : 'Nothing has been attached yet.',
                          style: TextStyle(
                            color: isDark
                                ? AppColors.darkTextSecondary
                                : AppColors.textSecondary,
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
                        itemCount: _attachments.length,
                        itemBuilder: (context, index) {
                          final attachment = _attachments[index];
                          final loading =
                              _loadingKey?.split(':').last ==
                              attachment.id.toString();
                          final selected = _selectedIds.contains(attachment.id);
                          return Card(
                            elevation: 0,
                            clipBehavior: Clip.antiAlias,
                            color: isDark ? AppColors.darkCardBg : Colors.white,
                            margin: const EdgeInsets.only(bottom: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(
                                color: selected
                                    ? AppColors.primary
                                    : (isDark
                                          ? AppColors.darkBorder
                                          : AppColors.border),
                              ),
                            ),
                            child: InkWell(
                              onTap: _selectionMode
                                  ? () => _toggleSelected(attachment.id)
                                  : null,
                              child: Padding(
                                padding: const EdgeInsets.all(10),
                                child: Row(
                                  children: [
                                    if (_selectionMode) ...[
                                      Checkbox(
                                        value: selected,
                                        onChanged: busy
                                            ? null
                                            : (_) => _toggleSelected(
                                                attachment.id,
                                              ),
                                      ),
                                      const SizedBox(width: 4),
                                    ],
                                    _Thumbnail(
                                      attachment: attachment,
                                      cookieHeader: _cookieHeader,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            attachment.fileName,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontWeight: FontWeight.w700,
                                              color: isDark
                                                  ? AppColors.darkTextPrimary
                                                  : AppColors.textPrimary,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            formatFileSize(
                                              attachment.sizeBytes,
                                            ),
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
                                    if (!_selectionMode && loading)
                                      const SizedBox(
                                        width: 22,
                                        height: 22,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      ),
                                    if (!_selectionMode && !loading) ...[
                                      _ActionIcon(
                                        icon: Icons.visibility,
                                        color: isDark
                                            ? AppColors.darkTextSecondary
                                            : AppColors.textSecondary,
                                        enabled: !busy,
                                        onTap: () => _view(attachment),
                                      ),
                                      _ActionIcon(
                                        icon: Icons.download,
                                        color: AppColors.primary,
                                        enabled: !busy,
                                        onTap: () => _download(attachment),
                                      ),
                                      if (widget.canManage)
                                        _ActionIcon(
                                          icon: Icons.delete,
                                          color: AppColors.error,
                                          enabled: !busy,
                                          onTap: () => _delete(attachment),
                                        ),
                                    ],
                                  ],
                                ),
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

  /// Matches MAX_FILE_SIZE in the backend attachments route — checked here so
  /// an oversized file fails fast instead of after a full upload.
  static const _maxUploadBytes = 10 * 1024 * 1024;

  Future<void> _upload() async {
    if (_loadingKey != null) return;
    final result = await FilePicker.pickFiles(
      type: widget.allowPdf ? FileType.custom : FileType.image,
      allowedExtensions: widget.allowPdf
          ? ['pdf', 'png', 'jpg', 'jpeg', 'webp', 'gif']
          : null,
      allowMultiple: true,
    );
    final files = result?.files ?? [];
    if (files.isEmpty) return;

    for (final file in files) {
      final path = file.path;
      if (path == null) continue;
      if (file.size > _maxUploadBytes) {
        setState(
          () => _error = '"${file.name}" exceeds the maximum size of 10 MB',
        );
        continue;
      }
      await _run(
        'upload:${file.name}',
        () async {
          final uploaded = await _repository.upload(
            ownerType: widget.ownerType,
            ownerId: widget.ownerId,
            filePath: path,
          );
          if (mounted) {
            setState(() => _attachments = [uploaded, ..._attachments]);
          }
        },
        actionType: 'upload',
        successMessage: 'Uploaded "${file.name}".',
      );
    }
  }

  Future<void> _delete(Attachment attachment) async {
    if (_loadingKey != null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => DeleteConfirmationDialog(
        title: 'Delete Attachment',
        targetName: attachment.fileName,
        warningText: 'This action cannot be undone.',
        warningSubtext: 'This file will be permanently removed.',
        confirmLabel: 'Delete',
      ),
    );
    if (confirmed != true) return;
    await _run(
      'delete:${attachment.id}',
      () async {
        await _repository.delete(attachment.id);
        if (mounted) {
          setState(
            () => _attachments = _attachments
                .where((a) => a.id != attachment.id)
                .toList(),
          );
        }
      },
      actionType: 'delete',
      successMessage: 'Attachment removed.',
    );
  }

  void _toggleSelectionMode() {
    setState(() {
      _selectionMode = !_selectionMode;
      _selectedIds = {};
    });
  }

  void _toggleSelected(int id) {
    setState(() {
      if (!_selectedIds.remove(id)) _selectedIds.add(id);
    });
  }

  void _toggleSelectAll() {
    setState(() {
      _selectedIds = _selectedIds.length == _attachments.length
          ? {}
          : _attachments.map((a) => a.id).toSet();
    });
  }

  Future<void> _downloadSelected() async {
    final selected = _attachments
        .where((a) => _selectedIds.contains(a.id))
        .toList();
    if (selected.isEmpty) return;
    final count = selected.length;
    await _run(
      'downloadZip:selection',
      () async {
        final zipPath = await _repository.downloadZip(
          selected,
          zipFileName:
              '${widget.ownerType.value}-${widget.ownerId}-attachments.zip',
        );
        final savedPath = await FileSaver.instance.saveAs(
          name: '${widget.ownerType.value}-${widget.ownerId}-attachments',
          filePath: zipPath,
          fileExtension: 'zip',
          mimeType: MimeType.zip,
        );
        if (savedPath == null) {
          // User backed out of the save dialog — not an error.
          throw _ActionCancelled();
        }
        if (mounted) {
          setState(() {
            _selectionMode = false;
            _selectedIds = {};
          });
        }
      },
      actionType: 'downloadZip',
      loadingMessage: 'Preparing $count file${count == 1 ? '' : 's'}...',
      successMessage: '$count file${count == 1 ? '' : 's'} downloaded!',
    );
  }

  Future<void> _view(Attachment attachment) async {
    await _run(
      'view:${attachment.id}',
      () async {
        final localPath = await _repository.download(
          attachment.id,
          fileName: attachment.fileName,
        );
        final result = await OpenFilex.open(localPath);
        if (result.type != ResultType.done) {
          throw Exception(
            result.type == ResultType.noAppToOpen
                ? 'No app available to open this file type'
                : 'Could not open file: ${result.message}',
          );
        }
      },
      actionType: 'view',
      loadingMessage: 'Opening file...',
    );
  }

  Future<void> _download(Attachment attachment) async {
    await _run(
      'download:${attachment.id}',
      () async {
        final localPath = await _repository.download(
          attachment.id,
          fileName: attachment.fileName,
        );
        final extension = attachment.fileName.split('.').last;
        final baseName = attachment.fileName.substring(
          0,
          attachment.fileName.length - extension.length - 1,
        );
        final mime = _mimeFor(extension);
        // Opens the native "Save As" dialog (Storage Access Framework on
        // Android, document picker on iOS) instead of just a share sheet.
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
      loadingMessage: 'Downloading file...',
    );
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
      if (actionType != 'view') {
        final successText = actionType == 'download'
            ? 'File downloaded successfully!'
            : (successMessage ?? 'Success!');
        if (mounted) {
          setState(() {
            _statusMessage = successText;
            _isSuccess = true;
          });
        }
        Future.delayed(const Duration(milliseconds: 2500), () {
          if (mounted && _statusMessage == successText) {
            setState(() => _statusMessage = null);
          }
        });
      } else if (mounted) {
        setState(() => _statusMessage = null);
      }
    } catch (e) {
      if (e is _ActionCancelled) {
        if (mounted) setState(() => _statusMessage = null);
      } else if (mounted) {
        setState(() {
          _error = e.toString().replaceFirst('Exception: ', '');
          _statusMessage = null;
        });
      }
    } finally {
      if (mounted) setState(() => _loadingKey = null);
    }
  }
}

/// Thrown internally when the user backs out of the native save dialog.
/// Not a real error — `_run` swallows it without showing the error banner.
class _ActionCancelled implements Exception {}

class _Thumbnail extends StatelessWidget {
  final Attachment attachment;
  final String? cookieHeader;

  const _Thumbnail({required this.attachment, required this.cookieHeader});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (!attachment.isImage || cookieHeader == null) {
      return Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: isDark
              ? AppColors.primary.withValues(alpha: 0.16)
              : AppColors.tileVehiclesBg,
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(
          AppIcons.fileText,
          color: AppColors.primary,
          size: 20,
        ),
      );
    }
    // CachedNetworkImage uses its own HTTP client, not Dio, so the session
    // cookie must be attached explicitly or this 401s silently.
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: CachedNetworkImage(
        imageUrl:
            '${ApiConstants.baseUrl}${ApiConstants.attachmentView}?id=${attachment.id}',
        httpHeaders: {'Cookie': cookieHeader!},
        width: 44,
        height: 44,
        fit: BoxFit.cover,
        placeholder: (_, _) => const SizedBox(
          width: 44,
          height: 44,
          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
        ),
        errorWidget: (_, _, _) => Container(
          width: 44,
          height: 44,
          color: isDark ? AppColors.darkBorder : AppColors.border,
          child: const Icon(AppIcons.fileText, size: 18),
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
        width: 34,
        height: 34,
        margin: const EdgeInsets.only(left: 6),
        decoration: BoxDecoration(
          color: effectiveColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: effectiveColor.withValues(alpha: 0.2)),
        ),
        child: Center(child: Icon(icon, color: effectiveColor, size: 16)),
      ),
    );
  }
}
