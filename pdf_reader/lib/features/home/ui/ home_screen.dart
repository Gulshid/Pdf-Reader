import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:pdf_reader/features/converter/bloc/converter_bloc.dart';
import 'package:pdf_reader/features/converter/bloc/converter_state.dart';
import 'package:pdf_reader/features/converter/ui/converter_screen.dart';
import 'package:pdf_reader/features/home/ui/file_tab.dart';
import 'package:pdf_reader/features/recent/bloc/recent_bloc.dart';
import 'package:pdf_reader/features/recent/bloc/recent_event.dart';
import 'package:pdf_reader/shared/models/pdf_file_model.dart';

import '../../../core/theme/theme_cubit.dart';
import '../bloc/home_bloc.dart';
import '../bloc/home_event.dart';
import '../../../shared/models/conversion_task_model.dart';
import '../../recent/ui/recent_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _navIndex = 0;

  // Keep all tab states alive with IndexedStack
  // ConverterScreen gets isEmbedded:true so it skips its own Scaffold/AppBar
  final List<Widget> _tabs = const [
    FilesTab(),
    ConverterScreen(isEmbedded: true),
    RecentScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return BlocListener<ConverterBloc, ConverterState>(
      listenWhen: (prev, curr) =>
          prev.status != curr.status &&
          curr.status == ConverterStatus.done,
      listener: (context, state) {
        // Bug Fix 3: Reload the Files tab so the converted file appears
        // immediately without needing a hot restart.
        context.read<HomeBloc>().add(const HomeLoadFilesEvent());

        // Bug Fix 2: Add the converted file to the Recent list so the
        // Recent tab shows it straight away.
        if (state.outputPath != null) {
          final outputFile = File(state.outputPath!);
          if (outputFile.existsSync()) {
            context.read<RecentBloc>().add(
                  RecentAddEvent(PdfFileModel.fromFile(outputFile)),
                );
          }
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            _appBarTitle(),
            style: theme.textTheme.titleLarge,
          ),
          actions: [
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

        // IndexedStack keeps all tabs mounted & preserves scroll/state
        body: IndexedStack(
          index: _navIndex,
          children: _tabs,
        ),

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

        // FAB only visible on Files tab
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
        1 => 'Convert',
        2 => 'Recent',
        _ => 'PDF Reader Pro',
      };
}