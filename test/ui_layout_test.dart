import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laantech_task/core/services/app_navigation.dart';
import 'package:laantech_task/core/theme/app_theme.dart';
import 'package:laantech_task/domain/entities/remote_file.dart';
import 'package:laantech_task/domain/entities/transfer_task.dart';
import 'package:laantech_task/domain/repositories/auth_repository.dart';
import 'package:laantech_task/presentation/bloc/auth/auth_bloc.dart';
import 'package:laantech_task/presentation/bloc/transfer/transfer_bloc.dart';
import 'package:laantech_task/presentation/bloc/transfer/transfer_state.dart';
import 'package:laantech_task/presentation/screens/auth/login_screen.dart';
import 'package:laantech_task/presentation/screens/dashboard/main_navigation_screen.dart';
import 'package:laantech_task/presentation/screens/download/download_complete_screen.dart';
import 'package:laantech_task/presentation/screens/splash/splash_screen.dart';

import 'transfer_test.dart' show FakeBackground, FakeNotifications, FakeRepo;

class _FakeAuth implements AuthRepository {
  @override
  Future<bool> isAuthenticated() async => false;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class SeededBloc extends TransferBloc {
  SeededBloc()
      : super(
          transferRepository: FakeRepo(),
          notificationService: FakeNotifications(),
          backgroundService: FakeBackground(),
        ) {
    TransferTask t(String id, TransferType type, TransferStatus s, {String? msg}) => TransferTask(
          id: id,
          fileName: 'very_long_product_catalog_export_2026_11_16_branch_dhaka_$id.csv',
          localFilePath: '/storage/emulated/0/Download/LAAN POS/x_$id.csv',
          type: type,
          status: s,
          totalBytes: 524288000,
          transferredBytes: 262144000,
          speedBytesPerSec: 3.4 * 1024 * 1024,
          message: msg,
          createdAt: DateTime(2026, 11, 16),
          completedAt: s == TransferStatus.completed ? DateTime(2026, 11, 16, 10) : null,
          remoteFileName: 'server_name_$id.csv',
          remoteUrl: 'http://108.136.142.112:90/get?file=server_name_$id.csv',
        );
    // ignore: invalid_use_of_visible_for_testing_member
    emit(TransferState(
      remoteFiles: const [
        RemoteFile(name: 'server_name_d1.csv', size: 524288000),
        RemoteFile(name: 'an_extremely_long_remote_file_name_for_audit_report_q4_2026.pdf', size: 1200),
      ],
      tasks: [
        t('u1', TransferType.upload, TransferStatus.running),
        t('u2', TransferType.upload, TransferStatus.retrying,
            msg: 'No connection to the server. Retrying in 8s (attempt 3 of 5)…'),
        t('u3', TransferType.upload, TransferStatus.completed),
        t('d1', TransferType.download, TransferStatus.paused, msg: 'Paused. Resuming continues from 250 MB.'),
        t('d2', TransferType.download, TransferStatus.failed, msg: 'File not found on the server.'),
        t('d3', TransferType.download, TransferStatus.completed),
      ],
    ));
  }
}

Widget app(Widget home, TransferBloc bloc) => MultiBlocProvider(
      providers: [
        BlocProvider<AuthBloc>(create: (_) => AuthBloc(authRepository: _FakeAuth())),
        BlocProvider<TransferBloc>.value(value: bloc),
      ],
      child: MaterialApp(theme: AppTheme.lightTheme, home: home),
    );

void main() {
  const sizes = {'phone': Size(360, 740), 'small-phone': Size(320, 640), 'tablet': Size(1280, 800)};

  for (final entry in sizes.entries) {
    testWidgets('all tabs render without overflow on ${entry.key}', (tester) async {
      tester.view.physicalSize = entry.value;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final bloc = SeededBloc();
      await tester.pumpWidget(app(const MainNavigationScreen(), bloc));
      for (final tab in AppTab.values) {
        AppNavigation.instance.goTo(tab);
        await tester.pump(const Duration(milliseconds: 300));
        final err = tester.takeException();
        if (err is FlutterError) debugPrint(err.toStringDeep());
        expect(err, isNull, reason: '${tab.name} on ${entry.key}');
      }
      AppNavigation.instance.goTo(AppTab.home);
      await tester.runAsync(bloc.close);
    });
  }

  testWidgets('login renders on a small phone', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(app(const LoginScreen(), SeededBloc()));
    await tester.tap(find.text('Register'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Confirm password'), findsOneWidget);
  });

  testWidgets('splash, download-complete and offline error pages render on a small phone', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final bloc = SeededBloc();

    await tester.pumpWidget(app(const SplashScreen(), bloc));
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(app(const DownloadCompleteScreen(taskId: 'd3'), bloc));
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.text('Download Complete!'), findsOneWidget);
    expect(find.text('Open File'), findsOneWidget);

    // ignore: invalid_use_of_visible_for_testing_member
    bloc.emit(const TransferState(filesError: 'No connection to the server. Check Wi-Fi / mobile data.'));
    AppNavigation.instance.goTo(AppTab.download);
    await tester.pumpWidget(app(const MainNavigationScreen(), bloc));
    await tester.pump(const Duration(milliseconds: 300));
    // ignore: invalid_use_of_visible_for_testing_member
    bloc.emit(const TransferState(filesError: 'No connection to the server. Check Wi-Fi / mobile data.'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
    expect(find.text('No Internet Connection'), findsOneWidget);
    AppNavigation.instance.goTo(AppTab.home);
    await tester.runAsync(bloc.close);
  });
}
