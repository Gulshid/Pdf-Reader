import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../core/di/injection_container.dart';
import '../features/converter/bloc/converter_bloc.dart';
import '../features/converter/ui/converter_screen.dart';
import '../features/home/ui/ home_screen.dart';
import '../features/pdf_viewer/ui/pdf_viewer_screen.dart';
import '../features/recent/ui/recent_screen.dart';
import '../features/splash/ui/splash_screen.dart';
import '../shared/models/pdf_file_model.dart';

abstract class AppRouter {
  static const splash = '/splash';
  static const home = '/';
  static const pdfViewer = '/pdf-viewer';
  static const converter = '/converter';
  static const recent = '/recent';

  static GoRouter create() => GoRouter(
        initialLocation: splash,
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
          GoRoute(
            path: converter,
            builder: (ctx, state) {
              final file = state.extra as PdfFileModel?;
              // Give the pushed converter screen its OWN isolated ConverterBloc.
              // Without this, it reads the global bloc that belongs to the tab,
              // causing state conflicts (wrong file shown, progress stuck, etc.).
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
        ],
      );
}