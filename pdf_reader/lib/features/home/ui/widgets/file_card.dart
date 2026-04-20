// ignore_for_file: unused_local_variable

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../shared/models/ pdf_file_model.dart';


class FileCard extends StatelessWidget {
  const FileCard({
    super.key,
    required this.file,
    required this.onTap,
    required this.onConvert,
    required this.onBookmark,
    required this.onDelete,
    this.isGrid = false,
  });

  final PdfFileModel file;
  final VoidCallback onTap;
  final VoidCallback onConvert;
  final VoidCallback onBookmark;
  final VoidCallback onDelete;
  final bool isGrid;

  @override
  Widget build(BuildContext context) {
    return isGrid ? _GridCard(this) : _ListCard(this);
  }
}

class _ListCard extends StatelessWidget {
  const _ListCard(this.widget);
  final FileCard widget;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16.r),
        onTap: widget.onTap,
        child: Padding(
          padding: EdgeInsets.all(12.w),
          child: Row(
            children: [
              _FileIcon(ext: widget.file.extension),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.file.name,
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      '${widget.file.sizeFormatted} • ${widget.file.dateFormatted}',
                      style: theme.textTheme.labelSmall,
                    ),
                  ],
                ),
              ),
              _ActionMenu(widget: widget),
            ],
          ),
        ),
      ),
    );
  }
}

class _GridCard extends StatelessWidget {
  const _GridCard(this.widget);
  final FileCard widget;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16.r),
        onTap: widget.onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _FileIcon(ext: widget.file.extension, size: 48.sp),
            SizedBox(height: 8.h),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 8.w),
              child: Text(
                widget.file.name,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
                maxLines: 2,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            SizedBox(height: 4.h),
            Text(widget.file.sizeFormatted, style: theme.textTheme.labelSmall),
            SizedBox(height: 4.h),
            _ActionMenu(widget: widget, isHorizontal: true),
          ],
        ),
      ),
    );
  }
}

class _FileIcon extends StatelessWidget {
  const _FileIcon({required this.ext, this.size});
  final String ext;
  final double? size;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = _colorForExt(ext);

    return Container(
      width: size ?? 44.sp,
      height: size ?? 44.sp,
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(10.r),
      ),
      child: Center(
        child: Text(
          ext,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w800,
            fontSize: (size ?? 44.sp) * 0.28,
          ),
        ),
      ),
    );
  }

  Color _colorForExt(String ext) => switch (ext) {
        'PDF' => const Color(0xFFE53935),
        'DOCX' || 'DOC' => const Color(0xFF1565C0),
        'TXT' => const Color(0xFF546E7A),
        'JPG' || 'JPEG' || 'PNG' => const Color(0xFF00897B),
        'CSV' => const Color(0xFF2E7D32),
        'XLSX' || 'XLS' => const Color(0xFF1B5E20),
        _ => const Color(0xFF6A1B9A),
      };
}

class _ActionMenu extends StatelessWidget {
  const _ActionMenu({required this.widget, this.isHorizontal = false});
  final FileCard widget;
  final bool isHorizontal;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert_rounded),
      onSelected: (value) {
        switch (value) {
          case 'convert':
            widget.onConvert();
          case 'bookmark':
            widget.onBookmark();
          case 'delete':
            widget.onDelete();
        }
      },
      itemBuilder: (_) => [
        PopupMenuItem(
          value: 'convert',
          child: Row(children: [
            const Icon(Icons.swap_horiz_rounded),
            SizedBox(width: 8.w),
            const Text('Convert'),
          ]),
        ),
        PopupMenuItem(
          value: 'bookmark',
          child: Row(children: [
            Icon(widget.file.isBookmarked
                ? Icons.bookmark_rounded
                : Icons.bookmark_outline_rounded),
            SizedBox(width: 8.w),
            Text(widget.file.isBookmarked ? 'Remove bookmark' : 'Bookmark'),
          ]),
        ),
        PopupMenuItem(
          value: 'delete',
          child: Row(children: [
            const Icon(Icons.delete_outline_rounded, color: Colors.red),
            SizedBox(width: 8.w),
            const Text('Remove', style: TextStyle(color: Colors.red)),
          ]),
        ),
      ],
    );
  }
}