// converter_bloc.dart

import 'dart:io';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:file_picker/file_picker.dart';

import '../../../core/utils/conversion_service.dart';
import '../../../core/utils/file_utils.dart';
import '../../../shared/models/pdf_file_model.dart';
import '../../../shared/models/conversion_task_model.dart';
import 'converter_event.dart';
import 'converter_state.dart';

class ConverterBloc extends Bloc<ConverterEvent, ConverterState> {
  ConverterBloc({required ConversionService conversionService})
      : _service = conversionService,
        super(const ConverterState()) {
    on<ConverterSetSourceEvent>(_onSetSource);
    on<ConverterPickSourceEvent>(_onPick);
    on<ConverterSetTargetFormatEvent>(_onSetTarget);
    on<ConverterStartEvent>(_onStart);
    on<ConverterResetEvent>(_onReset);
    on<_ProgressUpdate>(_onProgress);
  }

  final ConversionService _service;

  void _onSetSource(
      ConverterSetSourceEvent event, Emitter<ConverterState> emit) {
    final format = FileUtils.detectFormat(event.file.path);
    emit(state.copyWith(
      sourceFile: event.file,
      sourceFormat: format,
      targetFormat: null, // sentinel clears previous target
      status: ConverterStatus.idle,
    ));
  }

  Future<void> _onPick(
    ConverterPickSourceEvent event,
    Emitter<ConverterState> emit,
  ) async {
    emit(state.copyWith(status: ConverterStatus.picking));

    final FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: [
        'pdf', 'docx', 'txt', 'jpg', 'jpeg', 'png', 'csv', 'xlsx', 'pptx', // ✅ pptx added
      ],
    );

    if (result == null || result.files.first.path == null) {
      emit(state.copyWith(status: ConverterStatus.idle));
      return;
    }

    final file = PdfFileModel.fromFile(File(result.files.first.path!));
    final format = FileUtils.detectFormat(file.path);

    emit(state.copyWith(
      status: ConverterStatus.idle,
      sourceFile: file,
      sourceFormat: format,
      targetFormat: null, // clear stale target when new file picked
    ));
  }

  void _onSetTarget(
      ConverterSetTargetFormatEvent event, Emitter<ConverterState> emit) {
    emit(state.copyWith(targetFormat: event.format));
  }

  Future<void> _onStart(
      ConverterStartEvent event, Emitter<ConverterState> emit) async {
    if (!state.canConvert) return;

    emit(state.copyWith(status: ConverterStatus.running, progress: 0.0));

    try {
      final task = ConversionTaskModel(
        id: FileUtils.generateId(),
        sourceFilePath: state.sourceFile!.path,
        sourceFormat: state.sourceFormat!,
        targetFormat: state.targetFormat!,
      );

      final output = await _service.convert(
        task: task,
        onProgress: (p) => add(_ProgressUpdate(p)),
      );

      emit(state.copyWith(
        status: ConverterStatus.done,
        outputPath: output,
        progress: 1.0,
      ));
    } catch (e, st) {
      // Log stack trace in debug builds
      assert(() {
        // ignore: avoid_print
        print('ConversionService error: $e\n$st');
        return true;
      }());
      emit(state.copyWith(
        status: ConverterStatus.failed,
        error: e.toString(),
      ));
    }
  }

  void _onProgress(_ProgressUpdate event, Emitter<ConverterState> emit) {
    emit(state.copyWith(progress: event.progress));
  }

  void _onReset(ConverterResetEvent event, Emitter<ConverterState> emit) {
    emit(const ConverterState());
  }
}

/// Internal event — streams progress from ConversionService back into the BLoC.
class _ProgressUpdate extends ConverterEvent {
  const _ProgressUpdate(this.progress);
  final double progress;
  @override
  List<Object?> get props => [progress];
}