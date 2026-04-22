// conversion_task_model.dart

import 'package:equatable/equatable.dart';

// ── Supported Formats ────────────────────────────────────────────────────────

enum SupportedFormat {
  pdf,
  txt,
  jpg,
  png,
  csv,
  xlsx,
  docx,
  pptx; // ✅ NEW

  String get label => switch (this) {
        SupportedFormat.pdf  => 'PDF',
        SupportedFormat.txt  => 'TXT',
        SupportedFormat.jpg  => 'JPG',
        SupportedFormat.png  => 'PNG',
        SupportedFormat.csv  => 'CSV',
        SupportedFormat.xlsx => 'XLSX',
        SupportedFormat.docx => 'DOCX',
        SupportedFormat.pptx => 'PPTX', // ✅ NEW
      };

  // ignore: overridden_fields
  String get name => switch (this) {
        SupportedFormat.pdf  => 'pdf',
        SupportedFormat.txt  => 'txt',
        SupportedFormat.jpg  => 'jpg',
        SupportedFormat.png  => 'png',
        SupportedFormat.csv  => 'csv',
        SupportedFormat.xlsx => 'xlsx',
        SupportedFormat.docx => 'docx',
        SupportedFormat.pptx => 'pptx', // ✅ NEW
      };

  /// Returns the valid target formats for this source format.
  List<SupportedFormat> get availableTargets => switch (this) {
        SupportedFormat.pdf  => [
            SupportedFormat.txt,
            SupportedFormat.jpg,
            SupportedFormat.png,
            SupportedFormat.docx,
            SupportedFormat.xlsx,
            SupportedFormat.pptx, // ✅ NEW
          ],
        SupportedFormat.txt  => [
            SupportedFormat.pdf,
            SupportedFormat.docx,
            SupportedFormat.xlsx,
          ],
        SupportedFormat.jpg  => [
            SupportedFormat.pdf,
            SupportedFormat.png,
          ],
        SupportedFormat.png  => [
            SupportedFormat.pdf,
            SupportedFormat.jpg,
          ],
        SupportedFormat.csv  => [
            SupportedFormat.pdf,
            SupportedFormat.xlsx,
            SupportedFormat.txt,
          ],
        SupportedFormat.xlsx => [
            SupportedFormat.pdf,
            SupportedFormat.csv,
            SupportedFormat.txt,
          ],
        SupportedFormat.docx => [
            SupportedFormat.pdf,
            SupportedFormat.txt,
            SupportedFormat.xlsx,
          ],
        SupportedFormat.pptx => [ // ✅ NEW
            SupportedFormat.pdf,
            SupportedFormat.txt,
          ],
      };
}

enum ConversionStatus {
  idle,
  picking,
  running,
  done,
  failed;
}

typedef ConverterStatus = ConversionStatus;

// ── Task Model ────────────────────────────────────────────────────────────────

class ConversionTaskModel extends Equatable {
  const ConversionTaskModel({
    required this.id,
    required this.sourceFilePath,
    required this.sourceFormat,
    required this.targetFormat,
  });

  final String id;
  final String sourceFilePath;
  final SupportedFormat sourceFormat;
  final SupportedFormat targetFormat;

  @override
  List<Object?> get props => [id, sourceFilePath, sourceFormat, targetFormat];
}