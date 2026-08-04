import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Android API 36 manifest keeps least-privilege release surface', () {
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();
    final gradle = File('android/app/build.gradle.kts').readAsStringSync();

    expect(gradle, contains('applicationId = "tj.tajgo.app"'));
    expect(
      gradle,
      contains('compileSdk = maxOf(flutter.compileSdkVersion, 36)'),
    );
    expect(gradle, contains('targetSdk = maxOf(flutter.targetSdkVersion, 36)'));
    expect(manifest, contains('android.permission.POST_NOTIFICATIONS'));
    expect(manifest, contains('android:name=".MainActivity"'));
    expect(manifest, contains('android:exported="true"'));
    expect(manifest, isNot(contains('ACCESS_BACKGROUND_LOCATION')));
    expect(manifest, isNot(contains('FOREGROUND_SERVICE_LOCATION')));
    expect(manifest, isNot(contains('READ_EXTERNAL_STORAGE')));
    expect(manifest, isNot(contains('WRITE_EXTERNAL_STORAGE')));
    expect(manifest, isNot(contains('CAMERA')));
  });

  test('notification permission remains requested on demand', () {
    final service = File(
      'lib/core/services/push_notification_service.dart',
    ).readAsStringSync();
    expect(service, contains('_messaging.requestPermission()'));
    expect(service, contains('enableForUser'));
  });
}
