import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laantech_task/core/errors/transfer_exception.dart';
import 'package:laantech_task/data/datasources/transfer_remote_datasource.dart';

void main() {
  late HttpServer server;
  late Directory tmp;
  late TransferRemoteDataSourceImpl ds;
  final payload = Uint8List.fromList(List.generate(200 * 1024, (i) => i % 251));
  var honourRange = true;
  var lastRange = '';

  setUp(() async {
    honourRange = true;
    lastRange = '';
    tmp = await Directory.systemTemp.createTemp('dl_test');
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((req) async {
      final range = req.headers.value('range');
      lastRange = range ?? '';
      final res = req.response;
      if (req.uri.queryParameters['file'] != 'report.bin') {
        res.statusCode = 404;
        await res.close();
        return;
      }
      if (range != null && honourRange) {
        final start = int.parse(range.replaceAll(RegExp(r'[^0-9]'), ''));
        res.statusCode = 206;
        res.headers.set('content-range', 'bytes $start-${payload.length - 1}/${payload.length}');
        res.contentLength = payload.length - start;
        res.add(payload.sublist(start));
      } else {
        res.contentLength = payload.length;
        res.add(payload);
      }
      await res.close();
    });
    ds = TransferRemoteDataSourceImpl(
      dio: Dio(BaseOptions(baseUrl: 'http://${server.address.host}:${server.port}')),
    );
  });

  tearDown(() async {
    await server.close(force: true);
    await tmp.delete(recursive: true);
  });

  Future<void> download(String part, {CancelToken? ct, void Function(int, int)? onProgress}) =>
      ds.downloadFile(
        token: 't',
        remoteName: 'report.bin',
        partialPath: part,
        cancelToken: ct ?? CancelToken(),
        onProgress: onProgress ?? (_, _) {},
      );

  test('fresh download writes the full file', () async {
    final part = '${tmp.path}/a.part';
    await download(part);
    expect(await File(part).readAsBytes(), payload);
    expect(lastRange, isEmpty);
  });

  test('resumes from an existing partial file with a Range header', () async {
    final part = '${tmp.path}/b.part';
    await File(part).writeAsBytes(payload.sublist(0, 50000));
    int? firstReported;
    await download(part, onProgress: (d, t) => firstReported ??= d);
    expect(lastRange, 'bytes=50000-');
    expect(firstReported, 50000);
    expect(await File(part).readAsBytes(), payload);
  });

  test('restarts from zero when the server ignores Range (no corruption)', () async {
    honourRange = false;
    final part = '${tmp.path}/c.part';
    await File(part).writeAsBytes(payload.sublist(0, 50000));
    await download(part);
    expect(await File(part).readAsBytes(), payload);
  });

  test('cancelling mid-stream throws cancelled instead of completing', () async {
    final part = '${tmp.path}/d.part';
    final ct = CancelToken();
    final future = download(part, ct: ct, onProgress: (d, _) {
      if (d > 0 && !ct.isCancelled) ct.cancel();
    });
    await expectLater(
      future,
      throwsA(isA<TransferException>().having((e) => e.isCancelled, 'isCancelled', true)),
    );
    expect(await File(part).length(), lessThan(payload.length));
  });

  test('uses the absolute URL returned by /upload when available', () async {
    final part = '${tmp.path}/u.part';
    await ds.downloadFile(
      token: 't',
      remoteName: 'ignored-name.bin',
      partialPath: part,
      cancelToken: CancelToken(),
      onProgress: (_, _) {},
      url: 'http://${server.address.host}:${server.port}/get?file=report.bin',
    );
    expect(await File(part).readAsBytes(), payload);
  });

  test('404 maps to a friendly notFound error', () async {
    final call = ds.downloadFile(
      token: 't',
      remoteName: 'missing.bin',
      partialPath: '${tmp.path}/e.part',
      cancelToken: CancelToken(),
      onProgress: (_, _) {},
    );
    await expectLater(
      call,
      throwsA(isA<TransferException>().having((e) => e.kind, 'kind', TransferErrorKind.notFound)),
    );
  });
}
