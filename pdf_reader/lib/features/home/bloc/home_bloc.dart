import 'dart:io';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:file_picker/file_picker.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/utils/file_utils.dart';
import '../../../shared/models/pdf_file_model.dart';
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

  final _bookmarksBox = Hive.box<String>('bookmarks');

  // ✅ Add this box — open it in main.dart alongside 'bookmarks'
  final _deletedBox = Hive.box<String>('deleted_files');

  Future<void> _onLoad(HomeLoadFilesEvent event, Emitter<HomeState> emit) async {
    emit(state.copyWith(status: HomeStatus.loading));
    try {
      final dirs = <Directory>[];
      if (Platform.isAndroid) {
        dirs.add(Directory('/storage/emulated/0/Download'));
        dirs.add(Directory('/storage/emulated/0/Documents'));
      } else {
        final docs = await getApplicationDocumentsDirectory();
        dirs.add(docs);
      }

      final files = <PdfFileModel>[];
      for (final dir in dirs) {
        files.addAll(await FileUtils.scanDirectory(dir));
      }

      // ✅ Filter out previously deleted files
      final deletedIds = _deletedBox.values.toSet();
      final nonDeleted = files.where((f) => !deletedIds.contains(f.id)).toList();

      // Apply bookmarks
      final bookmarked = _bookmarksBox.values.toSet();
      final withBookmarks = nonDeleted
          .map((f) => f.copyWith(isBookmarked: bookmarked.contains(f.id)))
          .toList();

      final sorted = _applySortAndSearch(withBookmarks, state.sort, state.searchQuery);
      emit(state.copyWith(
        status: HomeStatus.loaded,
        allFiles: withBookmarks,
        filteredFiles: sorted,
      ));
    } catch (e) {
      emit(state.copyWith(status: HomeStatus.error, error: e.toString()));
    }
  }

  Future<void> _onPick(HomePickFileEvent event, Emitter<HomeState> emit) async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: ['pdf', 'docx', 'txt', 'jpg', 'jpeg', 'png', 'csv', 'xlsx'],
    );
    if (result == null) return;

    // ✅ If user re-picks a previously deleted file, remove it from deleted set
    final picked = result.files
        .where((f) => f.path != null)
        .map((f) => PdfFileModel.fromFile(File(f.path!)))
        .toList();

    for (final f in picked) {
      _deletedBox.delete(f.id); // allow re-adding
    }

    final all = [...state.allFiles, ...picked];
    final sorted = _applySortAndSearch(all, state.sort, state.searchQuery);
    emit(state.copyWith(allFiles: all, filteredFiles: sorted));
  }

  void _onSearch(HomeSearchEvent event, Emitter<HomeState> emit) {
    final filtered = _applySortAndSearch(state.allFiles, state.sort, event.query);
    emit(state.copyWith(searchQuery: event.query, filteredFiles: filtered));
  }

  void _onSort(HomeToggleSortEvent event, Emitter<HomeState> emit) {
    final sorted = _applySortAndSearch(state.allFiles, event.sort, state.searchQuery);
    emit(state.copyWith(sort: event.sort, filteredFiles: sorted));
  }

  void _onBookmark(HomeToggleBookmarkEvent event, Emitter<HomeState> emit) {
    final updated = state.allFiles.map((f) {
      if (f.id == event.fileId) {
        if (f.isBookmarked) {
          _bookmarksBox.delete(f.id);
        } else {
          _bookmarksBox.put(f.id, f.id);
        }
        return f.copyWith(isBookmarked: !f.isBookmarked);
      }
      return f;
    }).toList();

    final sorted = _applySortAndSearch(updated, state.sort, state.searchQuery);
    emit(state.copyWith(allFiles: updated, filteredFiles: sorted));
  }

  void _onDelete(HomeDeleteFileEvent event, Emitter<HomeState> emit) {
    // ✅ Persist the deletion so it survives hot restart / app restart
    _deletedBox.put(event.fileId, event.fileId);

    // Also clean up bookmark if it exists
    _bookmarksBox.delete(event.fileId);

    final updated = state.allFiles.where((f) => f.id != event.fileId).toList();
    final sorted = _applySortAndSearch(updated, state.sort, state.searchQuery);
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
      case HomeSort.nameAsc:
        result.sort((a, b) => a.name.compareTo(b.name));
      case HomeSort.nameDesc:
        result.sort((a, b) => b.name.compareTo(a.name));
      case HomeSort.dateAsc:
        result.sort((a, b) => a.lastModified.compareTo(b.lastModified));
      case HomeSort.dateDesc:
        result.sort((a, b) => b.lastModified.compareTo(a.lastModified));
      case HomeSort.sizeAsc:
        result.sort((a, b) => a.size.compareTo(b.size));
      case HomeSort.sizeDesc:
        result.sort((a, b) => b.size.compareTo(a.size));
    }
    return result;
  }
}