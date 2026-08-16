import 'dart:io';

import 'package:archive/archive.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/constants/api_constants.dart';
import '../../core/network/dio_client.dart';
import '../models/api_response.dart';
import 'attachment_models.dart';

/// Vehicle photos and client payment proofs share this one repository, one
/// bucket and one pair of routes — split only by [AttachmentOwnerType].
/// Modelled on `VehicleRepository`'s document methods; see that file's
/// `uploadDocument`/`downloadDocument` for the pattern this mirrors.
class AttachmentRepository {
  Dio get _dio => DioClient.dio;

  Future<List<Attachment>> fetchFor({
    required AttachmentOwnerType ownerType,
    required int ownerId,
  }) async {
    final response = await _dio.get(
      ApiConstants.attachments,
      queryParameters: {'owner_type': ownerType.value, 'owner_id': ownerId},
    );
    final data = unwrapResponse<Map<String, dynamic>>(
      response,
      fallbackError: 'Failed to load attachments',
    );
    return (data['data'] as List<dynamic>? ?? [])
        .map((e) => Attachment.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Attachment> upload({
    required AttachmentOwnerType ownerType,
    required int ownerId,
    required String filePath,
  }) async {
    final file = File(filePath);
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(file.path),
      'owner_type': ownerType.value,
      'owner_id': ownerId.toString(),
    });

    final response = await _dio.post(
      ApiConstants.attachments,
      data: formData,
      // Dio's BaseOptions default Content-Type is application/json — without
      // this override the multipart boundary is never emitted.
      options: Options(headers: {'Content-Type': 'multipart/form-data'}),
    );

    final data = unwrapResponse<Map<String, dynamic>>(
      response,
      fallbackError: 'Failed to upload file',
    );
    return Attachment.fromJson(data['attachment'] as Map<String, dynamic>);
  }

  Future<void> delete(int id) async {
    final response = await _dio.delete(
      ApiConstants.attachments,
      queryParameters: {'id': id},
    );
    unwrapResponse<dynamic>(
      response,
      fallbackError: 'Failed to delete attachment',
    );
  }

  /// Downloads to a temp file and returns its local path. The body is raw
  /// bytes, not the `{success, data}` envelope, so this bypasses
  /// [unwrapResponse] and checks the status code directly — same as
  /// `VehicleRepository.downloadDocument`.
  Future<String> download(int id, {required String fileName}) async {
    final dir = await getTemporaryDirectory();
    final savePath = '${dir.path}/$fileName';

    final response = await _dio.download(
      ApiConstants.attachmentView,
      savePath,
      queryParameters: {'id': id, 'download': 'true'},
      // A weak connection on a full-size photo can outlast the global 30s
      // receiveTimeout; this request gets more room.
      options: Options(receiveTimeout: const Duration(minutes: 2)),
    );

    if ((response.statusCode ?? 500) < 300) return savePath;
    throw Exception('Failed to download attachment');
  }

  /// Downloads several attachments and bundles them into one zip file,
  /// returning its local path. Each attachment is fetched to a per-id temp
  /// path (not `download()`'s fixed `fileName` path) so that two selected
  /// files sharing an original name can't clobber each other mid-fetch.
  Future<String> downloadZip(
    List<Attachment> attachments, {
    required String zipFileName,
  }) async {
    final dir = await getTemporaryDirectory();
    final archive = Archive();
    final usedNames = <String>{};

    for (final attachment in attachments) {
      final tempPath = '${dir.path}/zip_src_${attachment.id}';
      final response = await _dio.download(
        ApiConstants.attachmentView,
        tempPath,
        queryParameters: {'id': attachment.id, 'download': 'true'},
        options: Options(receiveTimeout: const Duration(minutes: 2)),
      );
      if ((response.statusCode ?? 500) >= 300) {
        throw Exception('Failed to download "${attachment.fileName}"');
      }

      final tempFile = File(tempPath);
      final bytes = await tempFile.readAsBytes();
      var name = attachment.fileName.isEmpty
          ? 'attachment-${attachment.id}'
          : attachment.fileName;
      if (usedNames.contains(name)) {
        final dot = name.lastIndexOf('.');
        name = dot > 0
            ? '${name.substring(0, dot)} (${attachment.id})${name.substring(dot)}'
            : '$name (${attachment.id})';
      }
      usedNames.add(name);
      archive.addFile(ArchiveFile(name, bytes.length, bytes));
      await tempFile.delete();
    }

    final zipBytes = ZipEncoder().encodeBytes(archive);
    final zipPath = '${dir.path}/$zipFileName';
    await File(zipPath).writeAsBytes(zipBytes);
    return zipPath;
  }
}
