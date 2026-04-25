import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:convert';

import '../../../core/services/reading_progress_service.dart';
import 'pdf_viewer_event.dart';
import 'pdf_viewer_state.dart';

class PdfViewerBloc extends Bloc<PdfViewerEvent, PdfViewerState> {
  PdfViewerBloc() : super(const PdfViewerState()) {
    on<PdfViewerLoadEvent>(_onLoad);
    on<PdfViewerDocumentLoadedEvent>(_onDocumentLoaded);
    on<PdfViewerPageChangedEvent>(_onPageChanged);
    on<PdfViewerZoomChangedEvent>(_onZoom);
    on<PdfViewerToggleNightModeEvent>(_onNightMode);
    on<PdfViewerToggleBookmarkEvent>(_onBookmark);
    on<PdfViewerJumpToPageEvent>(_onJump);
    on<PdfViewerShareEvent>(_onShare);
  }

  final _box = Hive.box<String>('bookmarks');
  String? _fileId; // cached for progress saves

  void _onLoad(PdfViewerLoadEvent event, Emitter<PdfViewerState> emit) {
    _fileId = event.path.hashCode.toString();

    final key = 'viewer_bookmarks_${event.path.hashCode}';
    final raw = _box.get(key);
    Set<int> bookmarks = {};
    if (raw != null) {
      final List<dynamic> list = jsonDecode(raw);
      bookmarks = list.cast<int>().toSet();
    }

    // Restore last-read page
    final progress = ReadingProgressService.get(_fileId!);
    final lastPage = progress?.currentPage ?? 0;

    emit(state.copyWith(
      status: PdfViewerStatus.loaded,
      filePath: event.path,
      bookmarkedPages: bookmarks,
      totalPages: 0,
      currentPage: lastPage,
    ));
  }

  void _onDocumentLoaded(
      PdfViewerDocumentLoadedEvent event, Emitter<PdfViewerState> emit) {
    emit(state.copyWith(totalPages: event.totalPages));
    // Update total in progress store
    if (_fileId != null) {
      ReadingProgressService.save(
        _fileId!,
        state.currentPage,
        totalPages: event.totalPages,
      );
    }
  }

  void _onPageChanged(
      PdfViewerPageChangedEvent event, Emitter<PdfViewerState> emit) {
    emit(state.copyWith(currentPage: event.page));
    // Persist progress on every page turn
    if (_fileId != null) {
      ReadingProgressService.save(
        _fileId!,
        event.page,
        totalPages: state.totalPages > 0 ? state.totalPages : null,
      );
    }
  }

  void _onZoom(
      PdfViewerZoomChangedEvent event, Emitter<PdfViewerState> emit) {
    emit(state.copyWith(zoom: event.zoom));
  }

  void _onNightMode(
      PdfViewerToggleNightModeEvent event, Emitter<PdfViewerState> emit) {
    emit(state.copyWith(isNightMode: !state.isNightMode));
  }

  void _onBookmark(
      PdfViewerToggleBookmarkEvent event, Emitter<PdfViewerState> emit) {
    final updated = Set<int>.from(state.bookmarkedPages);
    if (updated.contains(event.page)) {
      updated.remove(event.page);
    } else {
      updated.add(event.page);
    }
    final key = 'viewer_bookmarks_${state.filePath.hashCode}';
    _box.put(key, jsonEncode(updated.toList()));
    emit(state.copyWith(bookmarkedPages: updated));
  }

  void _onJump(
      PdfViewerJumpToPageEvent event, Emitter<PdfViewerState> emit) {
    emit(state.copyWith(currentPage: event.page));
  }

  Future<void> _onShare(
      PdfViewerShareEvent event, Emitter<PdfViewerState> emit) async {
    if (state.filePath != null) {
      await Share.shareXFiles([XFile(state.filePath!)]);
    }
  }
}
