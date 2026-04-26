import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:pdf_reader/features/bookmarks/ui/bookmarks_screen.dart';
import 'package:pdf_reader/features/converter/bloc/converter_bloc.dart';
import 'package:pdf_reader/features/converter/bloc/converter_state.dart';
import 'package:pdf_reader/features/converter/ui/converter_screen.dart';
import 'package:pdf_reader/features/home/ui/file_tab.dart';
import 'package:pdf_reader/features/recent/bloc/recent_bloc.dart';
import 'package:pdf_reader/features/recent/bloc/recent_event.dart';
import 'package:pdf_reader/shared/models/pdf_file_model.dart';


import '../../../core/services/intent_handler_service.dart';
import '../../../core/theme/theme_cubit.dart';
import '../../../routes/app_router.dart';
import '../../../shared/models/conversion_task_model.dart';
import '../bloc/home_bloc.dart';
import '../bloc/home_event.dart';
import '../../recent/ui/recent_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _navIndex = 0;
  StreamSubscription<ResolvedFile?>? _intentSub;

  final List<Widget> _tabs = const [
    FilesTab(),
    BookmarksScreen(isEmbedded: true),
    ConverterScreen(isEmbedded: true),
    RecentScreen(isEmbedded: true),
  ];

  @override
  void initState() {
    super.initState();
    // Listen for files shared/opened while app is already running
    _intentSub = IntentHandlerService.onNewFile.listen((resolved) {
      if (resolved != null && mounted) _openExternalFile(resolved.path, resolved.displayName);
    });
  }

  @override
  void dispose() {
    _intentSub?.cancel();
    super.dispose();
  }

  void _openExternalFile(String path, String displayName) {
    final file = PdfFileModel.fromFile(File(path), displayName: displayName);
    if (file.fileType == FileType.pdf) {
      context.push(AppRouter.pdfViewer, extra: file);
    } else {
      context.push(AppRouter.fileViewer, extra: file);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return BlocListener<ConverterBloc, ConverterState>(
      listenWhen: (prev, curr) =>
          prev.status != curr.status && curr.status == ConverterStatus.done,
      listener: (context, state) {
        context.read<HomeBloc>().add(const HomeLoadFilesEvent());
        if (state.outputPath != null) {
          final outputFile = File(state.outputPath!);
          if (outputFile.existsSync()) {
            context
                .read<RecentBloc>()
                .add(RecentAddEvent(PdfFileModel.fromFile(outputFile)));
          }
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_appBarTitle(), style: theme.textTheme.titleLarge),
          actions: [
            IconButton(
              icon: const Icon(Icons.settings_rounded),
              tooltip: 'Settings',
              onPressed: () => context.push(AppRouter.appLockSettings),
            ),
            IconButton(
              icon: Icon(
                theme.brightness == Brightness.dark
                    ? Icons.light_mode_rounded
                    : Icons.dark_mode_rounded,
              ),
              onPressed: () => context.read<ThemeCubit>().toggle(),
            ),
            SizedBox(width: 4.w),
          ],
        ),
        body: IndexedStack(index: _navIndex, children: _tabs),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _navIndex,
          onDestinationSelected: (i) => setState(() => _navIndex = i),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.folder_outlined),
              selectedIcon: Icon(Icons.folder_rounded),
              label: 'Files',
            ),
            NavigationDestination(
              icon: Icon(Icons.bookmark_outline_rounded),
              selectedIcon: Icon(Icons.bookmark_rounded),
              label: 'Bookmarks',
            ),
            NavigationDestination(
              icon: Icon(Icons.swap_horiz_outlined),
              selectedIcon: Icon(Icons.swap_horiz_rounded),
              label: 'Convert',
            ),
            NavigationDestination(
              icon: Icon(Icons.history_outlined),
              selectedIcon: Icon(Icons.history_rounded),
              label: 'Recent',
            ),
          ],
        ),
        floatingActionButton: _navIndex == 0
            ? FloatingActionButton.extended(
                onPressed: () =>
                    context.read<HomeBloc>().add(const HomePickFileEvent()),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Add File'),
              )
            : null,
      ),
    );
  }

  String _appBarTitle() => switch (_navIndex) {
        0 => 'PDF Reader Pro',
        1 => 'Bookmarks',
        2 => 'Convert',
        3 => 'Recent',
        _ => 'PDF Reader Pro',
      };
}