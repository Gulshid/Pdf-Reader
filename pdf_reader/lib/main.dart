import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'core/di/injection_container.dart';
import 'core/services/reading_progress_service.dart';
import 'pdf_reader_app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Lock to portrait + landscape (allow both)
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  

  // Init Hive
  await Hive.initFlutter();
  await _openHiveBoxes();

  // Init reading progress
  await ReadingProgressService.init();

  // Init DI
  await configureDependencies();

  runApp(const PdfReaderApp());
}

Future<void> _openHiveBoxes() async {
  await Hive.openBox<String>('bookmarks');
  await Hive.openBox<String>('deleted_files');
  await Hive.openBox<String>('recent_files');
  await Hive.openBox<String>('picked_files'); 
  await Hive.openBox('settings');
}