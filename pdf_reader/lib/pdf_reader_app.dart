
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:pdf_reader/core/di/injection_container.dart';
import 'package:pdf_reader/core/theme/app_theme.dart';
import 'package:pdf_reader/features/converter/bloc/converter_bloc.dart';
import 'package:pdf_reader/features/home/bloc/home_bloc.dart';
import 'package:pdf_reader/features/home/bloc/home_event.dart';
import 'package:pdf_reader/features/recent/bloc/recent_bloc.dart';
import 'package:pdf_reader/features/recent/bloc/recent_event.dart';
import 'package:pdf_reader/routes/app_router.dart';

import 'core/theme/theme_cubit.dart';

class PdfReaderApp extends StatefulWidget {
  const PdfReaderApp({super.key});

  @override
  State<PdfReaderApp> createState() => _PdfReaderAppState();
}

class _PdfReaderAppState extends State<PdfReaderApp>
    with WidgetsBindingObserver {
  late final _router = AppRouter.create();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => sl<ThemeCubit>()),
        BlocProvider(
          create: (_) => sl<HomeBloc>()..add(const HomeLoadFilesEvent()),
        ),
        BlocProvider(
          create: (_) => sl<RecentBloc>()..add(const RecentLoadEvent()),
        ),
        BlocProvider(create: (_) => sl<ConverterBloc>()),
      ],
      // LayoutBuilder and ScreenUtilInit are now OUTSIDE the theme listener.
      // They run once on first build and never again when theme changes.
      child: LayoutBuilder(
        builder: (context, constraints) {
          return ScreenUtilInit(
            designSize: _designSize(constraints.maxWidth),
            minTextAdapt: true,
            splitScreenMode: true,
            // Pass router down — _AppEntry owns the MaterialApp
            builder: (_, __) => _AppEntry(router: _router),
          );
        },
      ),
    );
  }
}

// This tiny widget is the ONLY thing that rebuilds on theme toggle.
// It has no children of its own — MaterialApp.router handles everything.
class _AppEntry extends StatelessWidget {
  const _AppEntry({required this.router});
  final RouterConfig<Object> router;

  @override
  Widget build(BuildContext context) {
    // context.watch() makes only THIS widget re-render, not LayoutBuilder
    // or ScreenUtilInit above it. Flutter diffs MaterialApp and updates
    // just the themeMode — the router and all screens stay mounted.
    final themeMode = context.watch<ThemeCubit>().state;

    return MaterialApp.router(
      title: 'PDF Reader Pro',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      routerConfig: router,
      builder: (ctx, child) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        SystemChrome.setSystemUIOverlayStyle(
          SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness:
                isDark ? Brightness.light : Brightness.dark,
            systemNavigationBarIconBrightness:
                isDark ? Brightness.light : Brightness.dark,
          ),
        );
        return child!;
      },
    );
  }
}

Size _designSize(double width) {
  if (width < 600) return const Size(360, 800);
  if (width < 1200) return const Size(834, 1194);
  return const Size(1440, 1024);
}