import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../core/di/injection_container.dart';
import '../features/app_lock/ui/app_lock_settings_screen.dart';
import '../features/bookmarks/ui/bookmarks_screen.dart';
import '../features/converter/bloc/converter_bloc.dart';
import '../features/converter/ui/converter_screen.dart';
import '../features/file_viewer/ui/file_viewer_screen.dart';
import '../features/home/ui/ home_screen.dart';
import '../features/pdf_viewer/ui/pdf_viewer_screen.dart';
import '../features/recent/ui/recent_screen.dart';
import '../features/splash/ui/splash_screen.dart';
import '../shared/models/pdf_file_model.dart';

abstract class AppRouter {
  static const splash          = '/splash';
  static const home            = '/';
  static const pdfViewer       = '/pdf-viewer';
  static const fileViewer      = '/file-viewer'; // ← new
  static const converter       = '/converter';
  static const recent          = '/recent';
  static const bookmarks       = '/bookmarks';
  static const appLockSettings = '/settings/app-lock';

  static const _knownRoutes = [
    splash, home, pdfViewer, fileViewer, converter, recent, bookmarks, appLockSettings,
  ];

  static GoRouter create() => GoRouter(
        initialLocation: splash,
        redirect: (context, state) {
          final loc = state.uri.toString();
          final isKnown = _knownRoutes.any((r) => loc == r || loc.startsWith('$r/'));
          if (!isKnown) return splash;
          return null;
        },
        routes: [
          GoRoute(
            path: splash,
            builder: (ctx, state) => const SplashScreen(),
          ),
          GoRoute(
            path: home,
            builder: (ctx, state) => const HomeScreen(),
          ),
          GoRoute(
            path: pdfViewer,
            builder: (ctx, state) {
              final file = state.extra as PdfFileModel;
              return PdfViewerScreen(file: file);
            },
          ),
          // Universal in-app viewer for all non-PDF formats
          GoRoute(
            path: fileViewer,
            builder: (ctx, state) {
              final file = state.extra as PdfFileModel;
              return FileViewerScreen(file: file);
            },
          ),
          GoRoute(
            path: converter,
            builder: (ctx, state) {
              final file = state.extra as PdfFileModel?;
              return BlocProvider(
                create: (_) => sl<ConverterBloc>(),
                child: ConverterScreen(initialFile: file),
              );
            },
          ),
          GoRoute(
            path: recent,
            builder: (ctx, state) => const RecentScreen(),
          ),
          GoRoute(
            path: bookmarks,
            builder: (ctx, state) => const BookmarksScreen(),
          ),
          GoRoute(
            path: appLockSettings,
            builder: (ctx, state) => const AppLockSettingsScreen(),
          ),
        ],
      );
}