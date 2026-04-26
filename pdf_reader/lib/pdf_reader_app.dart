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

  /// Timestamp when the app went inactive.
  /// Used to measure how long the app was away before resuming.
  DateTime? _inactiveAt;

  /// How long the app must be away before locking on resume.
  ///
  /// File picker / permission dialogs / share sheets / biometric prompts
  /// all return in well under 1 second on any device.
  /// A real backgrounding (home button, app switcher) keeps the app away
  /// for at least a few seconds minimum.
  ///
  /// 2 seconds is a safe threshold: long enough to ignore all system overlays,
  /// short enough to always lock when the user genuinely leaves the app.
  static const _lockThreshold = Duration(seconds: 2);

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

    if (state == AppLifecycleState.inactive && !_lockIsShowing) {
      // Record the moment we lost focus.
      // Fires for both real backgrounding AND system overlays (pickers etc.)
      // We use _inactiveAt = null check so we only record the FIRST inactive
      // event in a sequence (inactive → paused → hidden all fire in order).
      _inactiveAt ??= DateTime.now();
    }

    if (state == AppLifecycleState.resumed) {
      if (_lockIsShowing) {
        // Biometric/PIN prompt was on top — clear the timer and do nothing.
        _inactiveAt = null;
        return;
      }

      final wentInactiveAt = _inactiveAt;
      _inactiveAt = null;

      if (wentInactiveAt == null) return;

      final awayDuration = DateTime.now().difference(wentInactiveAt);

      // Only lock if the app was away longer than the threshold.
      // File pickers, permission dialogs, share sheets all return faster
      // than _lockThreshold so they will never trigger the lock.
      if (awayDuration >= _lockThreshold) {
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