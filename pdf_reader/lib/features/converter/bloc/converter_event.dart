import 'package:equatable/equatable.dart';
import '../../../shared/models/pdf_file_model.dart';
import '../../../shared/models/conversion_task_model.dart';

abstract class ConverterEvent extends Equatable {
  const ConverterEvent();
  @override
  List<Object?> get props => [];
}

class ConverterSetSourceEvent extends ConverterEvent {
  const ConverterSetSourceEvent(this.file);
  final PdfFileModel file;
  @override
  List<Object?> get props => [file];
}

class ConverterPickSourceEvent extends ConverterEvent {
  const ConverterPickSourceEvent();
}

class ConverterSetTargetFormatEvent extends ConverterEvent {
  const ConverterSetTargetFormatEvent(this.format);
  final SupportedFormat format;
  @override
  List<Object?> get props => [format];
}

class ConverterStartEvent extends ConverterEvent {
  const ConverterStartEvent();
}

class ConverterResetEvent extends ConverterEvent {
  const ConverterResetEvent();
}