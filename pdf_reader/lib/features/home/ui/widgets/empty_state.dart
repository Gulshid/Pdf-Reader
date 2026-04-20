import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../bloc/home_bloc.dart';
import '../../bloc/home_event.dart';

class EmptyState extends StatelessWidget {
  const EmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.folder_open_rounded,
            size: 80.sp,
            color: cs.primary.withOpacity(0.4),
          ),
          SizedBox(height: 16.h),
          Text('No files yet', style: theme.textTheme.titleLarge),
          SizedBox(height: 8.h),
          Text(
            'Tap the + button to add PDF, DOCX,\nimage, or text files.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: cs.onSurface.withOpacity(0.6),
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 24.h),
          ElevatedButton.icon(
            onPressed: () =>
                context.read<HomeBloc>().add(const HomePickFileEvent()),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add Files'),
          ),
        ],
      ),
    );
  }
}
