import 'package:equatable/equatable.dart';
import '../../../shared/models/pdf_file_model.dart';
import 'home_event.dart';

enum HomeStatus { initial, loading, loaded, error }

class HomeState extends Equatable {
  const HomeState({
    this.status = HomeStatus.initial,
    this.allFiles = const [],
    this.filteredFiles = const [],
    this.searchQuery = '',
    this.sort = HomeSort.dateDesc,
    this.error,
  });

  final HomeStatus status;
  final List<PdfFileModel> allFiles;
  final List<PdfFileModel> filteredFiles;
  final String searchQuery;
  final HomeSort sort;
  final String? error;

  HomeState copyWith({
    HomeStatus? status,
    List<PdfFileModel>? allFiles,
    List<PdfFileModel>? filteredFiles,
    String? searchQuery,
    HomeSort? sort,
    String? error,
  }) {
    return HomeState(
      status: status ?? this.status,
      allFiles: allFiles ?? this.allFiles,
      filteredFiles: filteredFiles ?? this.filteredFiles,
      searchQuery: searchQuery ?? this.searchQuery,
      sort: sort ?? this.sort,
      error: error ?? this.error,
    );
  }

  @override
  List<Object?> get props =>
      [status, allFiles, filteredFiles, searchQuery, sort, error];
}