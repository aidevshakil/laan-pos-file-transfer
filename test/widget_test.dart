import 'package:flutter_test/flutter_test.dart';
import 'package:laantech_task/core/utils/file_utils.dart';

void main() {
  test('Smoke test on FileUtils icon and formatting', () {
    expect(FileUtils.formatBytes(1024), '1.0 KB');
  });
}
