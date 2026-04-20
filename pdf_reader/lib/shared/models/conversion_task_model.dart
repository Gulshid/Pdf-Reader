import 'package:equatable/equatable.dart';

enum ConversionStatus { idle, running, done, failed }

enum SupportedFormat {
  pdf,
  docx,
  txt,
  jpg,
  png,
  csv,
  xlsx,
}

extension SupportedFormatExt on SupportedFormat {
  String get label => name.toUpperCase();
  String get mimeType => switch (this) {
        SupportedFormat.pdf => 'application/pdf',
        SupportedFormat.docx =>
          'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
        SupportedFormat.txt => 'text/plain',
        SupportedFormat.jpg => 'image/jpeg',
        SupportedFormat.png => 'image/png',
        SupportedFormat.csv => 'text/csv',
        SupportedFormat.xlsx =>
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      };
}

class ConversionTaskModel extends Equatable {
  const ConversionTaskModel({
    required this.id,
    required this.sourceFilePath,
    required this.sourceFormat,
    required this.targetFormat,
    this.status = ConversionStatus.idle,
    this.progress = 0.0,
    this.outputPath,
    this.error,
  });

  final String id;
  final String sourceFilePath;
  final SupportedFormat sourceFormat;
  final SupportedFormat targetFormat;
  final ConversionStatus status;
  final double progress;
  final String? outputPath;
  final String? error;

  ConversionTaskModel copyWith({
    String? id,
    String? sourceFilePath,
    SupportedFormat? sourceFormat,
    SupportedFormat? targetFormat,
    ConversionStatus? status,
    double? progress,
    String? outputPath,
    String? error,
  }) {
    return ConversionTaskModel(
      id: id ?? this.id,
      sourceFilePath: sourceFilePath ?? this.sourceFilePath,
      sourceFormat: sourceFormat ?? this.sourceFormat,
      targetFormat: targetFormat ?? this.targetFormat,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      outputPath: outputPath ?? this.outputPath,
      error: error ?? this.error,
    );
  }

  @override
  List<Object?> get props =>
      [id, sourceFilePath, sourceFormat, targetFormat, status, progress];
}