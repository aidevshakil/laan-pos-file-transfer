import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'core/constants/api_constants.dart';
import 'core/theme/app_theme.dart';
import 'core/utils/notification_service.dart';
import 'data/datasources/auth_remote_datasource.dart';
import 'data/datasources/transfer_remote_datasource.dart';
import 'data/repositories/auth_repository_impl.dart';
import 'data/repositories/transfer_repository_impl.dart';
import 'domain/repositories/auth_repository.dart';
import 'domain/repositories/transfer_repository.dart';
import 'presentation/bloc/auth/auth_bloc.dart';
import 'presentation/bloc/auth/auth_event.dart';
import 'presentation/bloc/transfer/transfer_bloc.dart';
import 'presentation/screens/auth/login_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize System Tray Notifications
  await NotificationService.instance.initialize();

  // Configure Dio Network Client
  final dio = Dio(
    BaseOptions(
      baseUrl: ApiConstants.defaultBaseUrl,
      connectTimeout: ApiConstants.connectTimeout,
      receiveTimeout: ApiConstants.receiveTimeout,
      sendTimeout: ApiConstants.sendTimeout,
      headers: {
        'Accept': 'application/json',
      },
    ),
  );

  // Setup Clean Architecture Data Sources
  final authRemoteDataSource = AuthRemoteDataSourceImpl(dio: dio);
  final transferRemoteDataSource = TransferRemoteDataSourceImpl(dio: dio);

  // Setup Repositories
  final AuthRepository authRepository = AuthRepositoryImpl(
    remoteDataSource: authRemoteDataSource,
  );

  final TransferRepository transferRepository = TransferRepositoryImpl(
    remoteDataSource: transferRemoteDataSource,
    authRepository: authRepository,
  );

  runApp(
    LaanPosApp(
      authRepository: authRepository,
      transferRepository: transferRepository,
    ),
  );
}

class LaanPosApp extends StatelessWidget {
  final AuthRepository authRepository;
  final TransferRepository transferRepository;

  const LaanPosApp({
    super.key,
    required this.authRepository,
    required this.transferRepository,
  });

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<AuthBloc>(
          create: (_) => AuthBloc(
            authRepository: authRepository,
          )..add(CheckAuthStatus()),
        ),
        BlocProvider<TransferBloc>(
          create: (_) => TransferBloc(
            transferRepository: transferRepository,
            notificationService: NotificationService.instance,
          ),
        ),
      ],
      child: MaterialApp(
        title: 'LAAN POS Transfer',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        home: const LoginScreen(),
      ),
    );
  }
}
