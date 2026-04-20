import 'package:equatable/equatable.dart';

abstract class PdfViewerEvent extends Equatable {
  const PdfViewerEvent();
  @override
  List<Object?> get props => [];
}

class PdfViewerLoadEvent extends PdfViewerEvent {
  const PdfViewerLoadEvent(this.path);
  final String path;
  @override
  List<Object?> get props => [path];
}

class PdfViewerPageChangedEvent extends PdfViewerEvent {
  const PdfViewerPageChangedEvent(this.page);
  final int page;
  @override
  List<Object?> get props => [page];
}

class PdfViewerZoomChangedEvent extends PdfViewerEvent {
  const PdfViewerZoomChangedEvent(this.zoom);
  final double zoom;
  @override
  List<Object?> get props => [zoom];
}

class PdfViewerToggleNightModeEvent extends PdfViewerEvent {
  const PdfViewerToggleNightModeEvent();
}

class PdfViewerToggleBookmarkEvent extends PdfViewerEvent {
  const PdfViewerToggleBookmarkEvent(this.page);
  final int page;
  @override
  List<Object?> get props => [page];
}

class PdfViewerJumpToPageEvent extends PdfViewerEvent {
  const PdfViewerJumpToPageEvent(this.page);
  final int page;
  @override
  List<Object?> get props => [page];
}

class PdfViewerShareEvent extends PdfViewerEvent {
  const PdfViewerShareEvent();
}