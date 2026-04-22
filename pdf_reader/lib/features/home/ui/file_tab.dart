// lib/features/home/presentation/screens/files_tab.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:pdf_reader/features/home/bloc/home_event.dart';
import 'package:pdf_reader/features/home/bloc/home_state.dart';
import 'package:pdf_reader/features/home/ui/widgets/empty_state.dart';

import 'package:open_filex/open_filex.dart';

import '../../../../routes/app_router.dart';
import '../../../shared/models/pdf_file_model.dart';
import '../bloc/home_bloc.dart';
import 'widgets/file_card.dart';

class FilesTab extends StatefulWidget {
  const FilesTab({super.key});

  @override
  State<FilesTab> createState() => _FilesTabState();
}

class _FilesTabState extends State<FilesTab> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Column(
      children: [
        // Search bar
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
          child: TextField(
            controller: _searchController,
            onChanged: (q) =>
                context.read<HomeBloc>().add(HomeSearchEvent(q)),
            decoration: InputDecoration(
              hintText: 'Search files…',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () {
                        _searchController.clear();
                        setState(() {}); // rebuild to hide X button
                        context
                            .read<HomeBloc>()
                            .add(const HomeSearchEvent(''));
                      },
                    )
                  : null,
            ),
          ),
        ),

        // Main content
        Expanded(
          child: BlocBuilder<HomeBloc, HomeState>(
            builder: (context, state) {
              if (state.status == HomeStatus.loading) {
                return const Center(child: CircularProgressIndicator());
              }

              if (state.status == HomeStatus.error) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.error_outline_rounded,
                          size: 48.sp, color: cs.error),
                      SizedBox(height: 12.h),
                      Text(state.error ?? 'Unknown error'),
                      SizedBox(height: 16.h),
                      ElevatedButton(
                        onPressed: () => context
                            .read<HomeBloc>()
                            .add(const HomeLoadFilesEvent()),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                );
              }

              if (state.filteredFiles.isEmpty) {
                return const EmptyState();
              }

              return Column(
                children: [
                  _SortBar(current: state.sort),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final isWide = constraints.maxWidth > 600;

                        if (isWide) {
                          return GridView.builder(
                            padding: EdgeInsets.all(16.w),
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount:
                                  constraints.maxWidth > 900 ? 4 : 2,
                              mainAxisSpacing: 12.h,
                              crossAxisSpacing: 12.w,
                              childAspectRatio: 0.75,
                            ),
                            itemCount: state.filteredFiles.length,
                            itemBuilder: (ctx, i) {
                              final file = state.filteredFiles[i];
                              return FileCard(
                                file: file,
                                isGrid: true,
                                onTap: () => _openFile(ctx, file),
                                onConvert: () => _openConverter(ctx, file),
                                onBookmark: () => ctx
                                    .read<HomeBloc>()
                                    .add(HomeToggleBookmarkEvent(file.id)),
                                onDelete: () => ctx
                                    .read<HomeBloc>()
                                    .add(HomeDeleteFileEvent(file.id)),
                              );
                            },
                          );
                        }

                        return ListView.separated(
                          padding: EdgeInsets.symmetric(
                              horizontal: 16.w, vertical: 8.h),
                          itemCount: state.filteredFiles.length,
                          separatorBuilder: (_, __) => SizedBox(height: 8.h),
                          itemBuilder: (ctx, i) {
                            final file = state.filteredFiles[i];
                            return FileCard(
                              file: file,
                              onTap: () => _openFile(ctx, file),
                              onConvert: () => _openConverter(ctx, file),
                              onBookmark: () => ctx
                                  .read<HomeBloc>()
                                  .add(HomeToggleBookmarkEvent(file.id)),
                              onDelete: () => ctx
                                  .read<HomeBloc>()
                                  .add(HomeDeleteFileEvent(file.id)),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  void _openFile(BuildContext context, PdfFileModel file) {
    if (file.extension.toUpperCase() == 'PDF') {
      context.push(AppRouter.pdfViewer, extra: file);
    } else {
      OpenFilex.open(file.path);
    }
  }

  void _openConverter(BuildContext context, PdfFileModel file) =>
      context.push(AppRouter.converter, extra: file);
}

class _SortBar extends StatelessWidget {
  const _SortBar({required this.current});
  final HomeSort current;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40.h,
      child: ListView(
        padding: EdgeInsets.symmetric(horizontal: 16.w),
        scrollDirection: Axis.horizontal,
        children: HomeSort.values.map((s) {
          return Padding(
            padding: EdgeInsets.only(right: 8.w),
            child: FilterChip(
              label: Text(_sortLabel(s)),
              selected: current == s,
              onSelected: (_) =>
                  context.read<HomeBloc>().add(HomeToggleSortEvent(s)),
            ),
          );
        }).toList(),
      ),
    );
  }

  String _sortLabel(HomeSort s) => switch (s) {
        HomeSort.nameAsc  => 'Name ↑',
        HomeSort.nameDesc => 'Name ↓',
        HomeSort.dateAsc  => 'Date ↑',
        HomeSort.dateDesc => 'Date ↓',
        HomeSort.sizeAsc  => 'Size ↑',
        HomeSort.sizeDesc => 'Size ↓',
      };
}