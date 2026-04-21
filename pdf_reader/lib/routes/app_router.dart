import 'package:go_router/go_router.dart';

import '../features/converter/ui/converter_screen.dart';
import '../features/home/ui/ home_screen.dart';
import '../features/pdf_viewer/ui/pdf_viewer_screen.dart';
import '../features/recent/ui/recent_screen.dart';
import '../shared/models/pdf_file_model.dart';

abstract class AppRouter {
  static const home = '/';
  static const pdfViewer = '/pdf-viewer';
  static const converter = '/converter';
  static const recent = '/recent';

  static GoRouter create() => GoRouter(
        initialLocation: home,
        routes: [
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
              return ConverterScreen(initialFile: file);
            },
          ),
          GoRoute(
            path: recent,
            builder: (ctx, state) => const RecentScreen(),
          ),
        ],
      );
}