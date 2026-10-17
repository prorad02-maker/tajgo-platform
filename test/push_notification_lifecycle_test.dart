import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:tajgo/core/services/push_notification_service.dart';

void main() {
  test('repeated bind keeps one active token refresh listener', () async {
    var activeListeners = 0;
    final controller = StreamController<String>.broadcast(
      onListen: () => activeListeners++,
      onCancel: () => activeListeners--,
    );
    final lifecycle = TokenRefreshLifecycle();
    final writes = <String>[];
    Future<void> store(String uid, String token) async {
      writes.add('$uid:$token');
    }

    await lifecycle.bind(
      uid: 'user-1',
      stream: controller.stream,
      onToken: store,
    );
    await lifecycle.bind(
      uid: 'user-1',
      stream: controller.stream,
      onToken: store,
    );
    expect(activeListeners, 1);

    controller.add('token-a');
    await pumpEventQueue();
    expect(writes, ['user-1:token-a']);

    await lifecycle.bind(
      uid: 'user-2',
      stream: controller.stream,
      onToken: store,
    );
    expect(activeListeners, 1);
    expect(lifecycle.activeUid, 'user-2');
    controller.add('token-b');
    await pumpEventQueue();
    expect(writes, ['user-1:token-a', 'user-2:token-b']);

    await lifecycle.unbind('user-2');
    expect(activeListeners, 0);
    controller.add('token-c');
    await pumpEventQueue();
    expect(writes, hasLength(2));

    await lifecycle.dispose();
    await controller.close();
  });
}
