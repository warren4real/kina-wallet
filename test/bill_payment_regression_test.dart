import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
// External persistence boundary; all screen and wallet logic stays real.
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/types.dart';
import 'package:kina_wallet/models/wallet_store.dart';
import 'package:kina_wallet/screens/electricity_screen.dart';
import 'package:kina_wallet/screens/water_screen.dart';

final class DelayedPreferences extends SharedPreferencesAsyncPlatform {
  final values = <String, String>{};
  Completer<void>? pending;
  @override
  Future<String?> getString(
    String key,
    SharedPreferencesOptions options,
  ) async => values[key];
  @override
  Future<void> setString(
    String key,
    String value,
    SharedPreferencesOptions options,
  ) async {
    await pending?.future;
    values[key] = value;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

void main() {
  final storage = DelayedPreferences();
  setUpAll(() async {
    SharedPreferencesAsyncPlatform.instance = storage;
    await walletStore.initialize();
  });
  for (final screen in [const ElectricityScreen(), const WaterScreen()]) {
    testWidgets(
      '${screen.runtimeType} prevents a second review while persistence is pending',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1400);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final before = walletStore.balanceToea;
        final count = walletStore.transactions.length;
        await tester.pumpWidget(MaterialApp(home: screen));
        await tester.enterText(find.byType(TextFormField).at(0), '12345678');
        await tester.enterText(find.byType(TextFormField).at(1), '10');
        await tester.tap(find.text('Review demo payment'));
        await tester.pumpAndSettle();
        storage.pending = Completer<void>();
        try {
          await tester.tap(find.text('Confirm demo payment'));
          await tester.pumpAndSettle();
          final review = find.widgetWithText(
            FilledButton,
            'Review demo payment',
          );
          expect(tester.widget<FilledButton>(review).onPressed, isNull);
          expect(walletStore.balanceToea, before);
        } finally {
          storage.pending!.complete();
          storage.pending = null;
          await tester.pumpAndSettle();
        }
        expect(walletStore.balanceToea, before - 1000);
        expect(walletStore.transactions.length, count + 1);
        expect(find.text('Demo payment recorded'), findsOneWidget);
      },
    );
  }
}
