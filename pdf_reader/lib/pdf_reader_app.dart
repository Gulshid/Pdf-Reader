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

import 'core/services/applock_service.dart';
import 'core/theme/theme_cubit.dart';
import 'features/app_lock/ui/applock_gate.dart';

class PdfReaderApp extends StatefulWidget {
  const PdfReaderApp({super.key});

  @override
  State<PdfReaderApp> createState() => _PdfReaderAppState();
}

class _PdfReaderAppState extends State<PdfReaderApp>
    with WidgetsBindingObserver {
  late final _router = AppRouter.create();

  // FIX: single flag that tracks whether the initial cold-start lock
  // has already been shown. The old code used _lockedOnResume which was
  // reset to false on every pause, so the `resumed` lifecycle event that
  // Android fires right after a cold start triggered a SECOND lock screen.
  bool _initialLockShown = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Show lock once on cold start
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _maybeShowLock();
      _initialLockShown = true; // mark done — resume events may now trigger
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Only trigger on resume AFTER the initial cold-start lock was handled.
    // This prevents the double-lock: cold-start fires postFrameCallback
    // AND a resumed event almost simultaneously.
    if (state == AppLifecycleState.resumed && _initialLockShown) {
      _maybeShowLock();
    }
  }

  Future<void> _maybeShowLock() async {
    if (!AppLockService.isEnabled) return;
    final ctx = _router.routerDelegate.navigatorKey.currentContext;
    if (ctx == null || !ctx.mounted) return;
    await AppLockGate.show(ctx);
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
      child: LayoutBuilder(
        builder: (context, constraints) {
          return ScreenUtilInit(
            designSize: _designSize(constraints.maxWidth),
            minTextAdapt: true,
            splitScreenMode: true,
            builder: (_, __) => _AppEntry(router: _router),
          );
        },
      ),
    );
  }
}

class _AppEntry extends StatelessWidget {
  const _AppEntry({required this.router});
  final RouterConfig<Object> router;

  @override
  Widget build(BuildContext context) {
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
