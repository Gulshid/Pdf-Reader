import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class BookmarkSheet extends StatelessWidget {
  const BookmarkSheet({
    super.key,
    required this.bookmarkedPages,
    required this.onJump,
  });

  final Set<int> bookmarkedPages;
  final ValueChanged<int> onJump;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DraggableScrollableSheet(
      initialChildSize: 0.5,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      expand: false,
      builder: (_, scrollController) {
        return Padding(
          padding: EdgeInsets.all(16.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40.w,
                  height: 4.h,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.onSurface.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(2.r),
                  ),
                ),
              ),
              SizedBox(height: 16.h),
              Text('Bookmarks', style: theme.textTheme.titleLarge),
              SizedBox(height: 8.h),
              if (bookmarkedPages.isEmpty)
                Center(
                  child: Padding(
                    padding: EdgeInsets.all(32.w),
                    child: Text(
                      'No bookmarks yet.\nTap the bookmark icon to add one.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.5),
                      ),
                    ),
                  ),
                )
              else
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    children: (bookmarkedPages.toList()..sort())
                        .map((page) => ListTile(
                              leading: Icon(Icons.bookmark_rounded,
                                  color: theme.colorScheme.primary),
                              title: Text('Page ${page + 1}'),
                              onTap: () => onJump(page),
                            ))
                        .toList(),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}