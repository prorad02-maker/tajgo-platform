import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tajgo/firebase_options.dart';

void main() {
  test('Android native and Dart configuration select the same Firebase app', () {
    final gradle = File('android/app/build.gradle.kts').readAsStringSync();
    final packageName = RegExp(
      r'applicationId\s*=\s*"([^"]+)"',
    ).firstMatch(gradle)!.group(1);
    final googleServices =
        jsonDecode(File('android/app/google-services.json').readAsStringSync())
            as Map<String, dynamic>;
    final client = (googleServices['client'] as List).cast<Map>().singleWhere(
      (client) =>
          client['client_info']['android_client_info']['package_name'] ==
          packageName,
    );
    final dartOptions = DefaultFirebaseOptions.android;
    expect(dartOptions.appId, client['client_info']['mobilesdk_app_id']);
    expect(dartOptions.apiKey, client['api_key'][0]['current_key']);
    expect(dartOptions.projectId, googleServices['project_info']['project_id']);
    expect(
      dartOptions.messagingSenderId,
      googleServices['project_info']['project_number'],
    );
    final firebase =
        jsonDecode(File('firebase.json').readAsStringSync()) as Map;
    expect(
      firebase['flutter']['platforms']['android']['default']['appId'],
      dartOptions.appId,
    );
    expect(
      firebase['flutter']['platforms']['dart']['lib/firebase_options.dart']['configurations']['android'],
      dartOptions.appId,
    );
  });
}
