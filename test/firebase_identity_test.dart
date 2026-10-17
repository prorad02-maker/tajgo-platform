import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tajgo/firebase_options.dart';

void main() {
  test('Android Firebase identity matches tj.tajgo.app native registration', () {
    const expectedProjectId = 'tajgo-4fcd0';
    const expectedPackage = 'tj.tajgo.app';

    final googleServices = jsonDecode(
      File('android/app/google-services.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    final projectInfo = googleServices['project_info'] as Map<String, dynamic>;
    final clients = (googleServices['client'] as List).cast<Map>();
    final nativeClient = clients.singleWhere(
      (client) =>
          ((client['client_info'] as Map)['android_client_info']
              as Map)['package_name'] ==
          expectedPackage,
    );
    final nativeAppId =
        (nativeClient['client_info'] as Map)['mobilesdk_app_id'] as String;

    final firebaseConfig = jsonDecode(
      File('firebase.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    final flutterPlatforms =
        ((firebaseConfig['flutter'] as Map)['platforms'] as Map);
    final configuredAndroid =
        ((flutterPlatforms['android'] as Map)['default'] as Map);
    final dartConfigurations =
        (((flutterPlatforms['dart'] as Map)['lib/firebase_options.dart'] as Map)
                ['configurations']
            as Map);

    final gradle = File('android/app/build.gradle.kts').readAsStringSync();

    expect(projectInfo['project_id'], expectedProjectId);
    expect(DefaultFirebaseOptions.android.projectId, expectedProjectId);
    expect(configuredAndroid['projectId'], expectedProjectId);
    expect(gradle, contains('applicationId = "$expectedPackage"'));
    expect(configuredAndroid['appId'], nativeAppId);
    expect(dartConfigurations['android'], nativeAppId);
    expect(DefaultFirebaseOptions.android.appId, nativeAppId);
    expect(
      clients.any(
        (client) =>
            ((client['client_info'] as Map)['android_client_info']
                as Map)['package_name'] ==
            'com.example.tajgo',
      ),
      isTrue,
      reason: 'Legacy registration must not be deleted automatically.',
    );
  });
}
