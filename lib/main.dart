import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/constants/api_constants.dart';
import 'core/services/app_navigation.dart';
import 'core/services/background_transfer_service.dart';
import 'core/theme/app_theme.dart';
import 'core/utils/notification_service.dart';
import 'data/datasources/auth_remote_datasource.dart';
import 'data/datasources/local_storage.dart';
import 'data/datasources/transfer_remote_datasource.dart';
import 'data/repositories/auth_repository_impl.dart';
import 'data/repositories/transfer_repository_impl.dart';
import 'domain/repositories/auth_repository.dart';
import 'domain/repositories/transfer_repository.dart';
import 'presentation/bloc/auth/auth_bloc.dart';
import 'presentation/bloc/auth/auth_state.dart';
import 'presentation/bloc/transfer/transfer_bloc.dart';
import 'presentation/bloc/transfer/transfer_event.dart';
import 'presentation/screens/auth/login_screen.dart';
import 'presentation/screens/dashboard/main_navigation_screen.dart';
import 'presentation/screens/splash/splash_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final storage = LocalStorage(await SharedPreferences.getInstance());
  await NotificationService.instance.initialize();
  BackgroundTransferService.instance.init();

  AppNavigation.instance.handlePayload(NotificationService.instance.launchPayload);

  final dio = Dio(
    BaseOptions(
      baseUrl: ApiConstants.defaultBaseUrl,
      connectTimeout: ApiConstants.connectTimeout,
      receiveTimeout: ApiConstants.receiveTimeout,
      sendTimeout: ApiConstants.sendTimeout,
      headers: {'Accept': 'application/json'},
    ),
  );

  final AuthRepository authRepository = AuthRepositoryImpl(
    remoteDataSource: AuthRemoteDataSourceImpl(dio: dio),
    storage: storage,
  );
  final TransferRepository transferRepository = TransferRepositoryImpl(
    remoteDataSource: TransferRemoteDataSourceImpl(dio: dio),
    authRepository: authRepository,
  );

  runApp(LaanPosApp(
    authRepository: authRepository,
    transferRepository: transferRepository,
    storage: storage,
  ));
}

class LaanPosApp extends StatelessWidget {
  final AuthRepository authRepository;
  final TransferRepository transferRepository;
  final LocalStorage storage;

  const LaanPosApp({
    super.key,
    required this.authRepository,
    required this.transferRepository,
    required this.storage,
  });

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<AuthBloc>(
          create: (_) => AuthBloc(authRepository: authRepository),
        ),
        BlocProvider<TransferBloc>(
          lazy: false,
          create: (_) => TransferBloc(
            transferRepository: transferRepository,
            notificationService: NotificationService.instance,
            backgroundService: BackgroundTransferService.instance,
            storage: storage,
          )..add(RestoreTransfers()),
        ),
      ],
      child: WithForegroundTask(
        child: MaterialApp(
          title: 'LAAN POS File Sync',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          home: const _AuthGate(),
        ),
      ),
    );
  }
}

class _AuthGate extends StatelessWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      buildWhen: (prev, next) =>
          (prev is AuthAuthenticated) != (next is AuthAuthenticated) ||
          prev is AuthInitial,
      builder: (context, state) {
        if (state is AuthInitial) {
          return const SplashScreen();
        }
        if (state is AuthAuthenticated) {
          return const MainNavigationScreen();
        }
        return const LoginScreen();
      },
    );
  }
}
