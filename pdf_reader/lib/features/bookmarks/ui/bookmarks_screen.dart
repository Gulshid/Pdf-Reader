import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../routes/app_router.dart';
import '../../../shared/models/pdf_file_model.dart';
import '../../home/bloc/home_bloc.dart';
import '../../home/bloc/home_event.dart';
import '../../home/bloc/home_state.dart';

class BookmarksScreen extends StatelessWidget {
  const BookmarksScreen({super.key, this.isEmbedded = false});
  final bool isEmbedded;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Widget body = BlocBuilder<HomeBloc, HomeState>(
      builder: (context, state) {
        final bookmarked =
            state.allFiles.where((f) => f.isBookmarked).toList();

        if (state.status == HomeStatus.loading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (bookmarked.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.bookmark_outline_rounded,
                    size: 64.sp, color: theme.colorScheme.outline),
                SizedBox(height: 16.h),
                Text(
                  'No bookmarks yet',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(color: theme.colorScheme.outline),
                ),
                SizedBox(height: 8.h),
                Text(
                  'Bookmark files from the Files tab\nor from the three-dot menu.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.outline),
                ),
              ],
            ),
          );
        }

        return ListView.separated(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
          itemCount: bookmarked.length,
          separatorBuilder: (_, __) => SizedBox(height: 8.h),
          itemBuilder: (ctx, i) {
            final file = bookmarked[i];
            return _BookmarkCard(file: file);
          },
        );
      },
    );

    if (isEmbedded) return body;

    return Scaffold(
      appBar: AppBar(title: const Text('Bookmarks')),
      body: body,
    );
  }
}

class _BookmarkCard extends StatelessWidget {
  const _BookmarkCard({required this.file});
  final PdfFileModel file;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16.r),
        onTap: () => _open(context),
        child: Padding(
          padding: EdgeInsets.all(12.w),
          child: Row(
            children: [
              // File type badge
              Container(
                width: 44.sp,
                height: 44.sp,
                decoration: BoxDecoration(
                  color: cs.primary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10.r),
                ),
                child: Center(
                  child: Text(
                    file.extension,
                    style: TextStyle(
                      color: cs.primary,
                      fontWeight: FontWeight.w800,
                      fontSize: 11.sp,
                    ),
                  ),
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      file.name,
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      '${file.sizeFormatted} · ${file.dateFormatted}',
                      style: theme.textTheme.labelSmall,
                    ),
                  ],
                ),
              ),
              // Unbookmark
              IconButton(
                icon: const Icon(Icons.bookmark_rounded),
                color: cs.primary,
                tooltip: 'Remove bookmark',
                onPressed: () => context
                    .read<HomeBloc>()
                    .add(HomeToggleBookmarkEvent(file.id)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _open(BuildContext context) {
    context.push(AppRouter.fileViewer, extra: file);
  }
}