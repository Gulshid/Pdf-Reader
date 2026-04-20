import 'package:equatable/equatable.dart';

enum PdfViewerStatus { initial, loading, loaded, error }

class PdfViewerState extends Equatable {
  const PdfViewerState({
    this.status = PdfViewerStatus.initial,
    this.filePath,
    this.totalPages = 0,
    this.currentPage = 0,
    this.zoom = 1.0,
    this.isNightMode = false,
    this.bookmarkedPages = const {},
    this.error,
  });

  final PdfViewerStatus status;
  final String? filePath;
  final int totalPages;
  final int currentPage;
  final double zoom;
  final bool isNightMode;
  final Set<int> bookmarkedPages;
  final String? error;

  bool get isCurrentPageBookmarked => bookmarkedPages.contains(currentPage);

  PdfViewerState copyWith({
    PdfViewerStatus? status,
    String? filePath,
    int? totalPages,
    int? currentPage,
    double? zoom,
    bool? isNightMode,
    Set<int>? bookmarkedPages,
    String? error,
  }) {
    return PdfViewerState(
      status: status ?? this.status,
      filePath: filePath ?? this.filePath,
      totalPages: totalPages ?? this.totalPages,
      currentPage: currentPage ?? this.currentPage,
      zoom: zoom ?? this.zoom,
      isNightMode: isNightMode ?? this.isNightMode,
      bookmarkedPages: bookmarkedPages ?? this.bookmarkedPages,
      error: error ?? this.error,
    );
  }

  @override
  List<Object?> get props =>
      [status, filePath, totalPages, currentPage, zoom, isNightMode, bookmarkedPages, error];
}