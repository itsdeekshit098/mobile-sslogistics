import '../utils/json_parse.dart';

/// Which parent record an attachment belongs to — matches `owner_type` on
/// the `GET/POST /api/attachments` query/form params.
enum AttachmentOwnerType {
  vehicle('vehicle'),
  clientEntry('client_entry'),
  loan('loan');

  final String value;
  const AttachmentOwnerType(this.value);
}

/// One row from the `attachments` table (sql/38_add_attachments.sql, extended
/// with loan_id by sql/44_add_loan_attachments.sql) — a vehicle photo, a
/// client payment proof, or a loan document. All three share this one model
/// and one pair of API routes, split only by which parent id is set.
class Attachment {
  final int id;
  final int? vehicleId;
  final int? clientEntryId;
  final int? loanId;
  final String fileName;
  final String mimeType;
  final int sizeBytes;
  final String? caption;
  final String createdAt;

  const Attachment({
    required this.id,
    required this.fileName,
    required this.mimeType,
    required this.sizeBytes,
    required this.createdAt,
    this.vehicleId,
    this.clientEntryId,
    this.loanId,
    this.caption,
  });

  bool get isImage => mimeType.startsWith('image/');

  factory Attachment.fromJson(Map<String, dynamic> json) => Attachment(
        id: parseId(json['id'])!,
        vehicleId: parseId(json['vehicle_id']),
        clientEntryId: parseId(json['client_entry_id']),
        loanId: parseId(json['loan_id']),
        fileName: json['file_name'] as String? ?? '',
        mimeType: json['mime_type'] as String? ?? 'application/octet-stream',
        sizeBytes: parseId(json['size_bytes']) ?? 0,
        caption: json['caption'] as String?,
        createdAt: json['created_at'] as String? ?? '',
      );

  @override
  bool operator ==(Object other) => other is Attachment && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

String formatFileSize(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}
