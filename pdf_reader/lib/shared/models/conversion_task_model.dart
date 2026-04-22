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
  pptx;

  String get label => switch (this) {
        SupportedFormat.pdf  => 'PDF',
        SupportedFormat.txt  => 'TXT',
        SupportedFormat.jpg  => 'JPG',
        SupportedFormat.png  => 'PNG',
        SupportedFormat.csv  => 'CSV',
        SupportedFormat.xlsx => 'XLSX',
        SupportedFormat.docx => 'DOCX',
        SupportedFormat.pptx => 'PPTX',
      };

  // FIX 1: Removed the broken `get name` override.
  // Dart enums already have a built-in `name` getter that returns the enum
  // member name as a string (e.g., SupportedFormat.pdf.name == 'pdf').
  // Overriding it with `// ignore: overridden_fields` was silently failing
  // on newer Dart SDKs (^3.8.1) because overriding a built-in getter this
  // way is not allowed. FileUtils.detectFormat() compares on `.name`, so
  // a broken override caused all format detection to return null, making
  // the Convert button permanently disabled.

  /// Returns the valid target formats for this source format.
  List<SupportedFormat> get availableTargets => switch (this) {
        SupportedFormat.pdf  => [
            SupportedFormat.txt,
            SupportedFormat.jpg,
            SupportedFormat.png,
            SupportedFormat.docx,
            SupportedFormat.xlsx,
            SupportedFormat.csv,   // FIX 2: CSV was listed as supported in
            SupportedFormat.pptx,  // _fromPdf but missing from availableTargets,
                                   // so the target button never appeared.
          ],
        SupportedFormat.txt  => [
            SupportedFormat.pdf,
            SupportedFormat.docx,
            SupportedFormat.xlsx,
            SupportedFormat.pptx,  // FIX 3: TXT→PPTX was implemented in the
                                   // service but missing from availableTargets.
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
        SupportedFormat.pptx => [
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