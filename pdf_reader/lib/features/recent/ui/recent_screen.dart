import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:open_filex/open_filex.dart';

import '../../../routes/app_router.dart';
import '../bloc/recent_bloc.dart';
import '../bloc/recent_event.dart';
import '../bloc/recent_state.dart';

class RecentScreen extends StatefulWidget {
  const RecentScreen({super.key, this.isEmbedded = false});
  final bool isEmbedded;

  @override
  State<RecentScreen> createState() => _RecentScreenState();
}

class _RecentScreenState extends State<RecentScreen> {
  @override
  void initState() {
    super.initState();
    // Reload recent files every time this screen is mounted so the tab
    // reflects files added during the session (e.g. after a conversion).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<RecentBloc>().add(const RecentLoadEvent());
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final actions = [
      BlocBuilder<RecentBloc, RecentState>(
        builder: (context, state) {
          if (state.files.isEmpty) return const SizedBox.shrink();
          return TextButton(
            onPressed: () =>
                context.read<RecentBloc>().add(const RecentClearEvent()),
            child: const Text('Clear All'),
          );
        },
      ),
    ];

    final body = BlocBuilder<RecentBloc, RecentState>(
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
                  onTap: () {
                    if (file.extension.toUpperCase() == 'PDF') {
                      ctx.push(AppRouter.pdfViewer, extra: file);
                    } else {
                      OpenFilex.open(file.path);
                    }
                  },
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
      );

    if (widget.isEmbedded) return body;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Recent Files'),
        actions: actions,
      ),
      body: body,
    );
  }
}