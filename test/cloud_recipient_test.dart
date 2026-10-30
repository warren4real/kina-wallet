import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:kina_wallet/models/recipient.dart';
import 'package:kina_wallet/models/recipient_store.dart';

import 'support/memory_preferences.dart';

class MemoryRecipients implements CloudRecipientGateway {
  final data = <String, List<Recipient>>{};
  Completer<List<Recipient>>? pending;
  bool fail = false;
  @override
  Future<List<Recipient>> load(String id) async {
    if (fail) throw StateError('Offline');
    if (pending != null) return pending!.future;
    return List.of(data[id] ?? []);
  }

  @override
  Future<void> save(String id, Recipient value, {String? originalPhone}) async {
    if (fail) throw StateError('Offline');
    final list = data.putIfAbsent(id, () => []);
    if (originalPhone != null) {
      list.removeWhere((r) => r.phoneNumber == originalPhone);
    }
    if (list.any((r) => r.phoneNumber == value.phoneNumber)) {
      throw StateError('Duplicate');
    }
    list.add(value);
  }

  @override
  Future<void> remove(String id, String phone) async {
    if (fail) throw StateError('Offline');
    data[id]?.removeWhere((r) => r.phoneNumber == phone);
  }
}

void main() {
  test('Cloud recipients are isolated, restored on another client, and local data is preserved', () async {
    final prefs = MemoryPreferences();
    final store = RecipientStore(preferences: prefs);
    await store.initialize();
    await store.addRecipient(name: 'Local', phoneNumber: '71111111');
    final original = Map.of(prefs.data);
    final cloud = MemoryRecipients();
    store.configureCloud(cloud);
    await store.useAccount('A');
    expect(store.recipients, isEmpty);
    expect(
      await store.addRecipient(name: 'Cloud A', phoneNumber: '72222222'),
      isNull,
    );
    final other = RecipientStore(preferences: MemoryPreferences());
    await other.initialize();
    other.configureCloud(cloud);
    await other.useAccount('A');
    expect(other.recipients.single.name, 'Cloud A');
    await store.useAccount('B');
    expect(store.recipients, isEmpty);
    await store.useAccount('A');
    expect(store.recipients.single.name, 'Cloud A');
    expect(
      await store.updateRecipient(
        originalPhoneNumber: '72222222',
        name: 'Renamed',
        phoneNumber: '73333333',
      ),
      isNull,
    );
    expect(store.recipients.single.name, 'Renamed');
    expect(await store.removeRecipient(phoneNumber: '73333333'), isNull);
    expect(store.recipients, isEmpty);
    await store.useAccount(null);
    expect(store.recipients.single.name, 'Local');
    expect(prefs.data, original);
  });
  test(
    'Old cloud responses cannot reveal recipients after changing accounts',
    () async {
      final store = RecipientStore(preferences: MemoryPreferences());
      await store.initialize();
      final cloud = MemoryRecipients()..pending = Completer<List<Recipient>>();
      store.configureCloud(cloud);
      final loading = store.useAccount('A');
      await store.useAccount(null);
      cloud.pending!.complete([
        const Recipient(name: 'Private A', phoneNumber: '72222222'),
      ]);
      await loading;
      expect(store.recipients, isEmpty);
    },
  );
  test(
    'Failed cloud loading blocks writes rather than using local recipients',
    () async {
      final store = RecipientStore(preferences: MemoryPreferences());
      await store.initialize();
      final cloud = MemoryRecipients()..fail = true;
      store.configureCloud(cloud);
      await store.useAccount('A');
      expect(store.error, isNotNull);
      expect(
        await store.addRecipient(name: 'A', phoneNumber: '72222222'),
        isNotNull,
      );
    },
  );
}
