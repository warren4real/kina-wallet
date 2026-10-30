import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:kina_wallet/screens/notifications_screen.dart';
import 'package:kina_wallet/models/transfer_notifications.dart';

class FakeNotifications implements TransferNotificationGateway {
  final reads = <String>{};
  Completer<NotificationSnapshot>? delayed;
  bool fail = false;
  @override
  Future<NotificationSnapshot> load(String owner) async {
    if (fail) throw Exception('offline');
    if (delayed != null) return delayed!.future;
    return NotificationSnapshot([
      TransferNotification(
        id: owner,
        title: 'Received K10',
        amountToea: 1000,
        createdAt: DateTime.utc(2026),
        reference: 'CLOUD-TRANSFER-1',
        isRead: reads.contains(owner),
      ),
    ], reads.contains(owner) ? 0 : 1);
  }

  @override
  Future<void> markRead(String owner, String id) async {
    reads.add(id);
  }
}

void main() {
  test(
    'read status persists through store recreation and stays account scoped',
    () async {
      final gateway = FakeNotifications();
      final store = TransferNotificationStore(gateway: gateway);
      await store.useAccount('A');
      expect(store.unreadCount, 1);
      await store.markRead('A');
      expect(store.unreadCount, 0);
      final reopened = TransferNotificationStore(gateway: gateway);
      await reopened.useAccount('A');
      expect(reopened.items.single.isRead, true);
      await reopened.useAccount('B');
      expect(reopened.unreadCount, 1);
      await reopened.useAccount(null);
      expect(reopened.items, isEmpty);
      expect(reopened.unreadCount, 0);
    },
  );
  test('late old-account response cannot populate a new account', () async {
    final gateway = FakeNotifications()
      ..delayed = Completer<NotificationSnapshot>();
    final old = gateway.delayed!;
    final store = TransferNotificationStore(gateway: gateway);
    final pending = store.useAccount('A');
    gateway.delayed = null;
    await store.useAccount('B');
    old.complete(NotificationSnapshot([], 99));
    await pending;
    expect(store.items.single.id, 'B');
    expect(store.unreadCount, 1);
  });
  test(
    'mark read during an in-flight poll cannot restore a stale unread badge',
    () async {
      final gateway = FakeNotifications();
      final store = TransferNotificationStore(gateway: gateway);
      await store.useAccount('A');
      final stale = Completer<NotificationSnapshot>();
      gateway.delayed = stale;
      final poll = store.refresh();
      await store.markRead('A');
      stale.complete(
        NotificationSnapshot([
          TransferNotification(
            id: 'A',
            title: 'Received',
            amountToea: 1000,
            createdAt: DateTime.utc(2026),
            reference: 'ref',
            isRead: false,
          ),
        ], 1),
      );
      await poll;
      expect(store.unreadCount, 0);
      expect(store.items.single.isRead, true);
    },
  );
  test(
    'offline refresh preserves alerts and read failures are recoverable',
    () async {
      final gateway = FakeNotifications();
      final store = TransferNotificationStore(gateway: gateway);
      await store.useAccount('A');
      gateway.fail = true;
      await store.refresh();
      expect(store.items.length, 1);
      expect(store.error, isNotNull);
      gateway.fail = false;
      await store.refresh();
      expect(store.error, isNull);
    },
  );
  testWidgets(
    'notification opens matching receipt and marks it read on a narrow screen',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final gateway = FakeNotifications();
      final store = TransferNotificationStore(gateway: gateway);
      await store.useAccount('A');
      await tester.pumpWidget(
        MaterialApp(home: NotificationsScreen(store: store)),
      );
      await tester.pumpAndSettle();
      expect(find.text('Received K10'), findsOneWidget);
      expect(find.byIcon(Icons.circle), findsOneWidget);
      await tester.tap(find.text('Received K10'));
      await tester.pumpAndSettle();
      expect(store.unreadCount, 0);
      expect(find.text('CLOUD-TRANSFER-1'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      store.dispose();
    },
  );
}
