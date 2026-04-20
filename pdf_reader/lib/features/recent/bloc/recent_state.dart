import 'package:equatable/equatable.dart';

import '../../../shared/models/ pdf_file_model.dart';

enum RecentStatus { initial, loading, loaded }

class RecentState extends Equatable {
  const RecentState({
    this.status = RecentStatus.initial,
    this.files = const [],
  });

  final RecentStatus status;
  final List<PdfFileModel> files;

  RecentState copyWith({
    RecentStatus? status,
    List<PdfFileModel>? files,
  }) {
    return RecentState(
      status: status ?? this.status,
      files: files ?? this.files,
    );
  }

  @override
  List<Object?> get props => [status, files];
}
