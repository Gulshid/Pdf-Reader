import 'dart:convert';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../../shared/models/ pdf_file_model.dart';
import 'recent_event.dart';
import 'recent_state.dart';

class RecentBloc extends Bloc<RecentEvent, RecentState> {
  RecentBloc() : super(const RecentState()) {
    on<RecentLoadEvent>(_onLoad);
    on<RecentAddEvent>(_onAdd);
    on<RecentClearEvent>(_onClear);
    on<RecentRemoveEvent>(_onRemove);
  }

  final _box = Hive.box<String>('recent_files');
  static const _maxRecent = 50;

  void _onLoad(RecentLoadEvent event, Emitter<RecentState> emit) {
    emit(state.copyWith(status: RecentStatus.loading));
    final files = _box.values
        .map((json) {
          try {
            return PdfFileModel.fromJson(
                jsonDecode(json) as Map<String, dynamic>);
          } catch (_) {
            return null;
          }
        })
        .whereType<PdfFileModel>()
        .toList();
    files.sort((a, b) => b.lastModified.compareTo(a.lastModified));
    emit(state.copyWith(status: RecentStatus.loaded, files: files));
  }

  void _onAdd(RecentAddEvent event, Emitter<RecentState> emit) {
    _box.put(event.file.id, jsonEncode(event.file.toJson()));
    final updated = [
      event.file,
      ...state.files.where((f) => f.id != event.file.id),
    ].take(_maxRecent).toList();
    emit(state.copyWith(files: updated));
  }

  void _onClear(RecentClearEvent event, Emitter<RecentState> emit) {
    _box.clear();
    emit(state.copyWith(files: []));
  }

  void _onRemove(RecentRemoveEvent event, Emitter<RecentState> emit) {
    _box.delete(event.fileId);
    final updated = state.files.where((f) => f.id != event.fileId).toList();
    emit(state.copyWith(files: updated));
  }
}