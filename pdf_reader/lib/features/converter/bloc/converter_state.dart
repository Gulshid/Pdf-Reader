import 'package:equatable/equatable.dart';
import '../../../shared/models/pdf_file_model.dart';
import '../../../shared/models/conversion_task_model.dart';

enum ConverterStatus { idle, picking, running, done, error }

class ConverterState extends Equatable {
  const ConverterState({
    this.status = ConverterStatus.idle,
    this.sourceFile,
    this.sourceFormat,
    this.targetFormat,
    this.progress = 0.0,
    this.outputPath,
    this.error,
  });

  final ConverterStatus status;
  final PdfFileModel? sourceFile;
  final SupportedFormat? sourceFormat;
  final SupportedFormat? targetFormat;
  final double progress;
  final String? outputPath;
  final String? error;

  List<SupportedFormat> get availableTargets {
    if (sourceFormat == null) return [];
    return switch (sourceFormat!) {
      SupportedFormat.pdf => [
          SupportedFormat.txt,
          SupportedFormat.jpg,
          SupportedFormat.png,
        ],
      SupportedFormat.txt => [SupportedFormat.pdf],
      SupportedFormat.jpg ||
      SupportedFormat.png =>
        [SupportedFormat.pdf, SupportedFormat.jpg, SupportedFormat.png],
      SupportedFormat.csv => [SupportedFormat.pdf],
      SupportedFormat.xlsx => [SupportedFormat.pdf],
      SupportedFormat.docx => [SupportedFormat.pdf],
    };
  }

  bool get canConvert =>
      sourceFile != null && targetFormat != null && status == ConverterStatus.idle;

  ConverterState copyWith({
    ConverterStatus? status,
    PdfFileModel? sourceFile,
    SupportedFormat? sourceFormat,
    SupportedFormat? targetFormat,
    double? progress,
    String? outputPath,
    String? error,
  }) {
    return ConverterState(
      status: status ?? this.status,
      sourceFile: sourceFile ?? this.sourceFile,
      sourceFormat: sourceFormat ?? this.sourceFormat,
      targetFormat: targetFormat ?? this.targetFormat,
      progress: progress ?? this.progress,
      outputPath: outputPath ?? this.outputPath,
      error: error ?? this.error,
    );
  }

  @override
  List<Object?> get props =>
      [status, sourceFile, sourceFormat, targetFormat, progress, outputPath, error];
}