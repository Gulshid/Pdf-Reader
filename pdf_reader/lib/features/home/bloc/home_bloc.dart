import 'dart:io';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:file_picker/file_picker.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/utils/file_utils.dart';
import '../../../shared/models/pdf_file_model.dart' hide FileType;
import 'home_event.dart';
import 'home_state.dart';

class HomeBloc extends Bloc<HomeEvent, HomeState> {
  HomeBloc() : super(const HomeState()) {
    on<HomeLoadFilesEvent>(_onLoad);
    on<HomePickFileEvent>(_onPick);
    on<HomeSearchEvent>(_onSearch);
    on<HomeToggleSortEvent>(_onSort);
    on<HomeToggleBookmarkEvent>(_onBookmark);
    on<HomeDeleteFileEvent>(_onDelete);
  }

  final _bookmarksBox  = Hive.box<String>('bookmarks');
  final _deletedBox    = Hive.box<String>('deleted_files');
  // ✅ Persists paths of user-picked files across restarts
  final _pickedBox     = Hive.box<String>('picked_files');

  Future<void> _onLoad(
      HomeLoadFilesEvent event, Emitter<HomeState> emit) async {
    emit(state.copyWith(status: HomeStatus.loading));
    try {
      // 1. Scan well-known directories
      final dirs = <Directory>[];
      if (Platform.isAndroid) {
        dirs.add(Directory('/storage/emulated/0/Download'));
        dirs.add(Directory('/storage/emulated/0/Documents'));
      } else {
        dirs.add(await getApplicationDocumentsDirectory());
      }

      final scanned = <PdfFileModel>[];
      for (final dir in dirs) {
        scanned.addAll(await FileUtils.scanDirectory(dir));
      }

      // 2. Re-hydrate user-picked files from Hive
      //    Skip paths that no longer exist on disk
      final pickedFiles = <PdfFileModel>[];
      for (final path in _pickedBox.values) {
        final f = File(path);
        if (await f.exists()) {
          pickedFiles.add(PdfFileModel.fromFile(f));
        } else {
          // File was deleted externally — clean up
          _pickedBox.delete(path);
        }
      }

      // 3. Merge, deduplicate by id (path hash)
      final seen  = <String>{};
      final merged = <PdfFileModel>[];
      for (final f in [...scanned, ...pickedFiles]) {
        if (seen.add(f.id)) merged.add(f);
      }

      // 4. Filter user-deleted entries
      final deletedIds = _deletedBox.values.toSet();
      final visible = merged.where((f) => !deletedIds.contains(f.id)).toList();

      // 5. Apply bookmarks
      final bookmarked = _bookmarksBox.values.toSet();
      final withBookmarks = visible
          .map((f) => f.copyWith(isBookmarked: bookmarked.contains(f.id)))
          .toList();

      final sorted =
          _applySortAndSearch(withBookmarks, state.sort, state.searchQuery);

      emit(state.copyWith(
        status: HomeStatus.loaded,
        allFiles: withBookmarks,
        filteredFiles: sorted,
      ));
    } catch (e) {
      emit(state.copyWith(status: HomeStatus.error, error: e.toString()));
    }
  }

  Future<void> _onPick(
      HomePickFileEvent event, Emitter<HomeState> emit) async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: ['pdf', 'docx', 'txt', 'jpg', 'jpeg', 'png', 'csv', 'xlsx', 'pptx'],
    );
    if (result == null) return;

    final picked = result.files
        .where((f) => f.path != null)
        .map((f) => PdfFileModel.fromFile(File(f.path!)))
        .toList();

    for (final f in picked) {
      // ✅ Persist path so it survives restarts
      _pickedBox.put(f.id, f.path);
      // Re-allow a previously deleted file
      _deletedBox.delete(f.id);
    }

    // Merge with existing, avoiding duplicates
    final existingIds = state.allFiles.map((f) => f.id).toSet();
    final newFiles = picked.where((f) => !existingIds.contains(f.id)).toList();

    final all    = [...state.allFiles, ...newFiles];
    final sorted = _applySortAndSearch(all, state.sort, state.searchQuery);
    emit(state.copyWith(allFiles: all, filteredFiles: sorted));
  }

  void _onSearch(HomeSearchEvent event, Emitter<HomeState> emit) {
    final filtered =
        _applySortAndSearch(state.allFiles, state.sort, event.query);
    emit(state.copyWith(searchQuery: event.query, filteredFiles: filtered));
  }

  void _onSort(HomeToggleSortEvent event, Emitter<HomeState> emit) {
    final sorted =
        _applySortAndSearch(state.allFiles, event.sort, state.searchQuery);
    emit(state.copyWith(sort: event.sort, filteredFiles: sorted));
  }

  void _onBookmark(
      HomeToggleBookmarkEvent event, Emitter<HomeState> emit) {
    final updated = state.allFiles.map((f) {
      if (f.id != event.fileId) return f;
      if (f.isBookmarked) {
        _bookmarksBox.delete(f.id);
      } else {
        _bookmarksBox.put(f.id, f.id);
      }
      return f.copyWith(isBookmarked: !f.isBookmarked);
    }).toList();

    final sorted =
        _applySortAndSearch(updated, state.sort, state.searchQuery);
    emit(state.copyWith(allFiles: updated, filteredFiles: sorted));
  }

  void _onDelete(HomeDeleteFileEvent event, Emitter<HomeState> emit) {
    // Persist deletion
    _deletedBox.put(event.fileId, event.fileId);
    // Remove from picked box too so it won't resurface on next load
    _pickedBox.delete(event.fileId);
    _bookmarksBox.delete(event.fileId);

    final updated = state.allFiles.where((f) => f.id != event.fileId).toList();
    final sorted  =
        _applySortAndSearch(updated, state.sort, state.searchQuery);
    emit(state.copyWith(allFiles: updated, filteredFiles: sorted));
  }

  List<PdfFileModel> _applySortAndSearch(
    List<PdfFileModel> files,
    HomeSort sort,
    String query,
  ) {
    var result = query.isEmpty
        ? List<PdfFileModel>.from(files)
        : files
            .where((f) => f.name.toLowerCase().contains(query.toLowerCase()))
            .toList();

    switch (sort) {
      case HomeSort.nameAsc:  result.sort((a, b) => a.name.compareTo(b.name));
      case HomeSort.nameDesc: result.sort((a, b) => b.name.compareTo(a.name));
      case HomeSort.dateAsc:  result.sort((a, b) => a.lastModified.compareTo(b.lastModified));
      case HomeSort.dateDesc: result.sort((a, b) => b.lastModified.compareTo(a.lastModified));
      case HomeSort.sizeAsc:  result.sort((a, b) => a.size.compareTo(b.size));
      case HomeSort.sizeDesc: result.sort((a, b) => b.size.compareTo(a.size));
    }
    return result;
  }
}