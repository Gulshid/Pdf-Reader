import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../routes/app_router.dart';
import '../../../core/theme/theme_cubit.dart';
import '../../../shared/models/ pdf_file_model.dart';
import '../bloc/home_bloc.dart';
import '../bloc/home_event.dart';
import '../bloc/home_state.dart';
import 'widgets/file_card.dart';
import 'widgets/empty_state.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _searchController = TextEditingController();
  int _navIndex = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'PDF Reader Pro',
          style: theme.textTheme.titleLarge,
        ),
        actions: [
          IconButton(
            icon: Icon(
              Theme.of(context).brightness == Brightness.dark
                  ? Icons.light_mode_rounded
                  : Icons.dark_mode_rounded,
            ),
            onPressed: () => context.read<ThemeCubit>().toggle(),
          ),
          IconButton(
            icon: const Icon(Icons.history_rounded),
            onPressed: () => context.go(AppRouter.recent),
          ),
          SizedBox(width: 4.w),
        ],
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(56.h),
          child: Padding(
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
                          context
                              .read<HomeBloc>()
                              .add(const HomeSearchEvent(''));
                        },
                      )
                    : null,
              ),
            ),
          ),
        ),
      ),
      body: BlocBuilder<HomeBloc, HomeState>(
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
                          crossAxisCount: constraints.maxWidth > 900 ? 4 : 2,
                          mainAxisSpacing: 12.h,
                          crossAxisSpacing: 12.w,
                          childAspectRatio: 0.75,
                        ),
                        itemCount: state.filteredFiles.length,
                        itemBuilder: (ctx, i) => FileCard(
                          file: state.filteredFiles[i],
                          isGrid: true,
                          onTap: () => _openFile(ctx, state.filteredFiles[i]),
                          onConvert: () => _openConverter(
                              ctx, state.filteredFiles[i]),
                          onBookmark: () => ctx.read<HomeBloc>().add(
                              HomeToggleBookmarkEvent(
                                  state.filteredFiles[i].id)),
                          onDelete: () => ctx.read<HomeBloc>().add(
                              HomeDeleteFileEvent(state.filteredFiles[i].id)),
                        ),
                      );
                    }
                    return ListView.separated(
                      padding: EdgeInsets.symmetric(
                          horizontal: 16.w, vertical: 8.h),
                      itemCount: state.filteredFiles.length,
                      separatorBuilder: (_, __) => SizedBox(height: 8.h),
                      itemBuilder: (ctx, i) => FileCard(
                        file: state.filteredFiles[i],
                        onTap: () => _openFile(ctx, state.filteredFiles[i]),
                        onConvert: () =>
                            _openConverter(ctx, state.filteredFiles[i]),
                        onBookmark: () => ctx.read<HomeBloc>().add(
                            HomeToggleBookmarkEvent(
                                state.filteredFiles[i].id)),
                        onDelete: () => ctx.read<HomeBloc>().add(
                            HomeDeleteFileEvent(state.filteredFiles[i].id)),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _navIndex,
        onDestinationSelected: (i) {
          setState(() => _navIndex = i);
          if (i == 1) context.go(AppRouter.converter);
          if (i == 2) context.go(AppRouter.recent);
        },
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () =>
            context.read<HomeBloc>().add(const HomePickFileEvent()),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add File'),
      ),
    );
  }

  void _openFile(BuildContext context, PdfFileModel file) {
    context.push(AppRouter.pdfViewer, extra: file);
  }

  void _openConverter(BuildContext context, PdfFileModel file) {
    context.push(AppRouter.converter, extra: file);
  }
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
          final isSelected = current == s;
          return Padding(
            padding: EdgeInsets.only(right: 8.w),
            child: FilterChip(
              label: Text(_sortLabel(s)),
              selected: isSelected,
              onSelected: (_) => context
                  .read<HomeBloc>()
                  .add(HomeToggleSortEvent(s)),
            ),
          );
        }).toList(),
      ),
    );
  }

  String _sortLabel(HomeSort s) => switch (s) {
        HomeSort.nameAsc => 'Name ↑',
        HomeSort.nameDesc => 'Name ↓',
        HomeSort.dateAsc => 'Date ↑',
        HomeSort.dateDesc => 'Date ↓',
        HomeSort.sizeAsc => 'Size ↑',
        HomeSort.sizeDesc => 'Size ↓',
      };
}