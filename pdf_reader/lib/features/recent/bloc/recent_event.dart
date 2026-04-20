import 'package:equatable/equatable.dart';
import '../../../shared/models/ pdf_file_model.dart';

abstract class RecentEvent extends Equatable {
  const RecentEvent();
  @override
  List<Object?> get props => [];
}

class RecentLoadEvent extends RecentEvent {
  const RecentLoadEvent();
}

class RecentAddEvent extends RecentEvent {
  const RecentAddEvent(this.file);
  final PdfFileModel file;
  @override
  List<Object?> get props => [file];
}

class RecentClearEvent extends RecentEvent {
  const RecentClearEvent();
}

class RecentRemoveEvent extends RecentEvent {
  const RecentRemoveEvent(this.fileId);
  final String fileId;
  @override
  List<Object?> get props => [fileId];
}