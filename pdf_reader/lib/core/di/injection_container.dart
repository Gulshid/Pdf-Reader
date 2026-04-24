import 'package:get_it/get_it.dart';

import '../theme/theme_cubit.dart';
import '../utils/conversion_service.dart';
import '../../features/converter/bloc/converter_bloc.dart';
import '../../features/home/bloc/home_bloc.dart';
import '../../features/recent/bloc/recent_bloc.dart';

final sl = GetIt.instance;

Future<void> configureDependencies() async {
  // Services
  sl.registerLazySingleton<ConversionService>(() =>  ConversionService());

  // Cubits / Blocs
  sl.registerFactory<ThemeCubit>(() => ThemeCubit());
  sl.registerFactory<HomeBloc>(() => HomeBloc());
  sl.registerFactory<RecentBloc>(() => RecentBloc());
  sl.registerFactory<ConverterBloc>(
    () => ConverterBloc(conversionService: sl<ConversionService>()),
  );
}