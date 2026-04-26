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

  bool _initialLockShown = false;
  static bool _lockIsShowing = false;

  /// True only after the app has genuinely gone to background (paused)
  /// AFTER the lock was last dismissed. This prevents the `resumed` event
  /// that fires after biometric/PIN unlock from immediately re-locking.
  bool _wentToBackgroundAfterUnlock = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _maybeShowLock();
      _initialLockShown = true;
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_initialLockShown) return;

    if (state == AppLifecycleState.paused && !_lockIsShowing) {
      // App genuinely went to background while unlocked.
      // Now we are allowed to lock on next resume.
      _wentToBackgroundAfterUnlock = true;
    }

    if (state == AppLifecycleState.resumed) {
      if (_lockIsShowing) return; // biometric dialog — ignore

      if (_wentToBackgroundAfterUnlock) {
        _wentToBackgroundAfterUnlock = false;
        _maybeShowLock();
      }
    }
  }

  Future<void> _maybeShowLock() async {
    if (!AppLockService.isEnabled) return;
    if (_lockIsShowing) return;
    _lockIsShowing = true;

    try {
      final ctx = _router.routerDelegate.navigatorKey.currentContext;
      if (ctx == null || !ctx.mounted) return;
      await AppLockGate.show(ctx);
    } finally {
      _lockIsShowing = false;
    }
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