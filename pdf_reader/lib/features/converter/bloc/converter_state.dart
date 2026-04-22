// converter_state.dart

import 'package:equatable/equatable.dart';
import '../../../shared/models/pdf_file_model.dart';
import '../../../shared/models/conversion_task_model.dart';

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

  bool get canConvert =>
      sourceFile != null &&
      sourceFormat != null &&
      targetFormat != null &&
      status != ConverterStatus.running;

  /// Available conversion targets based on detected source format.
  List<SupportedFormat> get availableTargets =>
      sourceFormat?.availableTargets ?? [];

  // ✅ FIX: Use a sentinel object to allow clearing nullable fields like
  //    targetFormat back to null (required when source file changes).
  static const _clear = Object();

  ConverterState copyWith({
    ConverterStatus? status,
    PdfFileModel? sourceFile,
    SupportedFormat? sourceFormat,
    Object? targetFormat = _clear, // sentinel default
    double? progress,
    String? outputPath,
    String? error,
  }) {
    return ConverterState(
      status: status ?? this.status,
      sourceFile: sourceFile ?? this.sourceFile,
      sourceFormat: sourceFormat ?? this.sourceFormat,
      // If caller passed null explicitly → clear it; if omitted → keep old
      targetFormat: identical(targetFormat, _clear)
          ? this.targetFormat
          : targetFormat as SupportedFormat?,
      progress: progress ?? this.progress,
      outputPath: outputPath ?? this.outputPath,
      error: error ?? this.error,
    );
  }

  @override
  List<Object?> get props => [
        status,
        sourceFile,
        sourceFormat,
        targetFormat,
        progress,
        outputPath,
        error,
      ];
}