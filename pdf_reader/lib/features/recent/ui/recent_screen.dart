import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../routes/app_router.dart';
import '../bloc/recent_bloc.dart';
import '../bloc/recent_event.dart';
import '../bloc/recent_state.dart';

class RecentScreen extends StatelessWidget {
  const RecentScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Recent Files'),
        actions: [
          BlocBuilder<RecentBloc, RecentState>(
            builder: (context, state) {
              if (state.files.isEmpty) return const SizedBox.shrink();
              return TextButton(
                onPressed: () => context
                    .read<RecentBloc>()
                    .add(const RecentClearEvent()),
                child: const Text('Clear All'),
              );
            },
          ),
        ],
      ),
      body: BlocBuilder<RecentBloc, RecentState>(
        builder: (context, state) {
          if (state.files.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.history_rounded,
                      size: 64.sp,
                      color: cs.primary.withOpacity(0.3)),
                  SizedBox(height: 16.h),
                  Text('No recent files', style: theme.textTheme.titleLarge),
                ],
              ),
            );
          }
          return ListView.separated(
            padding:
                EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
            itemCount: state.files.length,
            separatorBuilder: (_, __) => SizedBox(height: 8.h),
            itemBuilder: (ctx, i) {
              final file = state.files[i];
              return Card(
                child: ListTile(
                  onTap: () => ctx.push(AppRouter.pdfViewer, extra: file),
                  leading: Container(
                    width: 40.w,
                    height: 40.w,
                    decoration: BoxDecoration(
                      color: cs.primary.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                    child: Center(
                      child: Text(
                        file.extension,
                        style: TextStyle(
                          color: cs.primary,
                          fontWeight: FontWeight.w800,
                          fontSize: 9.sp,
                        ),
                      ),
                    ),
                  ),
                  title: Text(
                    file.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    '${file.sizeFormatted} • ${file.dateFormatted}',
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => ctx
                        .read<RecentBloc>()
                        .add(RecentRemoveEvent(file.id)),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}