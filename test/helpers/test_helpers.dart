import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sprout_aac/main.dart';
import 'package:sprout_aac/models/database.dart';
import 'package:sprout_aac/services/symbol_service.dart';
import 'package:sprout_aac/services/tts_service.dart';

// ── Mocks ───────────────────────────────────────────────────────────────────

class MockSymbolService extends Mock implements SymbolService {}

class MockTtsService extends Mock implements TtsService {}

// ── Database ─────────────────────────────────────────────────────────────────

AppDatabase makeTestDb() => AppDatabase.forTesting(NativeDatabase.memory());

// ── Provider overrides ────────────────────────────────────────────────────────

List<Override> dbOverride(AppDatabase db) => [dbProvider.overrideWithValue(db)];

List<Override> allOverrides({
  required AppDatabase db,
  required MockSymbolService symbols,
  required MockTtsService tts,
}) =>
    [
      dbProvider.overrideWithValue(db),
      symbolServiceProvider.overrideWithValue(symbols),
      ttsServiceProvider.overrideWithValue(tts),
    ];

// ── Stub helpers ─────────────────────────────────────────────────────────────

void stubSymbolService(MockSymbolService svc,
    {List<AacSymbol> results = const []}) {
  when(() => svc.search(any())).thenAnswer((_) async => results);
  when(() => svc.getById(any())).thenAnswer((_) async => null);
  when(() => svc.initialize()).thenAnswer((_) async {});
}

void stubTtsService(MockTtsService svc) {
  when(() => svc.initialize(
        rate: any(named: 'rate'),
        pitch: any(named: 'pitch'),
        volume: any(named: 'volume'),
        voiceIdentifier: any(named: 'voiceIdentifier'),
      )).thenAnswer((_) async {});
  when(() => svc.speak(any())).thenAnswer((_) async {});
  when(() => svc.stop()).thenAnswer((_) async {});
  when(() => svc.applySettings(
        rate: any(named: 'rate'),
        pitch: any(named: 'pitch'),
        volume: any(named: 'volume'),
        voiceIdentifier: any(named: 'voiceIdentifier'),
      )).thenAnswer((_) async {});
  when(() => svc.getAvailableVoices()).thenAnswer((_) async => []);
  when(() => svc.dispose()).thenReturn(null);
}

// ── FlutterSecureStorage mock ─────────────────────────────────────────────────
// Mocks the platform channel used by FlutterSecureStorage in widget tests.

void mockSecureStorage({String? storedPin}) {
  const channel =
      MethodChannel('plugins.it_expertise.com/flutter_secure_storage');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, (call) async {
    switch (call.method) {
      case 'read':
        return storedPin;
      case 'write':
        return null;
      case 'delete':
        return null;
      case 'containsKey':
        return storedPin != null;
      default:
        return null;
    }
  });
}

void clearSecureStorageMock() {
  const channel =
      MethodChannel('plugins.it_expertise.com/flutter_secure_storage');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, null);
}
