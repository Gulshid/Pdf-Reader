import 'package:equatable/equatable.dart';

abstract class HomeEvent extends Equatable {
  const HomeEvent();
  @override
  List<Object?> get props => [];
}

class HomeLoadFilesEvent extends HomeEvent {
  const HomeLoadFilesEvent();
}

class HomePickFileEvent extends HomeEvent {
  const HomePickFileEvent();
}

class HomeSearchEvent extends HomeEvent {
  const HomeSearchEvent(this.query);
  final String query;
  @override
  List<Object?> get props => [query];
}

class HomeToggleSortEvent extends HomeEvent {
  const HomeToggleSortEvent(this.sort);
  final HomeSort sort;
  @override
  List<Object?> get props => [sort];
}

class HomeToggleBookmarkEvent extends HomeEvent {
  const HomeToggleBookmarkEvent(this.fileId);
  final String fileId;
  @override
  List<Object?> get props => [fileId];
}

class HomeDeleteFileEvent extends HomeEvent {
  const HomeDeleteFileEvent(this.fileId);
  final String fileId;
  @override
  List<Object?> get props => [fileId];
}

enum HomeSort { nameAsc, nameDesc, dateAsc, dateDesc, sizeAsc, sizeDesc }