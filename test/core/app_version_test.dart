import 'package:flutter_test/flutter_test.dart';
import 'package:nutrition_app/core/app_version.dart';

void main() {
  test('splits the build number out of the pubspec version', () {
    expect(appVersionLabel('0.0.0+2'), '0.0.0 (build 2)');
    expect(appVersionLabel('1.2.3+45'), '1.2.3 (build 45)');
  });

  test('a version without a build number reads as is', () {
    expect(appVersionLabel('0.1.0'), '0.1.0');
  });

  test('a build without a version says so', () {
    expect(appVersionLabel(''), 'Development build');
    expect(appVersionLabel('  '), 'Development build');
  });
}
