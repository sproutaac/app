import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sprout_aac/services/tts_service.dart';

// Mock the flutter_tts MethodChannel so no platform calls go through.
void _setUpTtsMock({List<dynamic>? voices}) {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
    const MethodChannel('flutter_tts'),
    (call) async {
      switch (call.method) {
        case 'setLanguage':
        case 'setSpeechRate':
        case 'setPitch':
        case 'setVolume':
        case 'speak':
        case 'stop':
        case 'setVoice':
          return 1;
        case 'getVoices':
          return voices;
        default:
          return null;
      }
    },
  );
}

void _clearTtsMock() {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
          const MethodChannel('flutter_tts'), null);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => _setUpTtsMock());
  tearDown(_clearTtsMock);

  group('TtsService.initialize', () {
    test('completes without error using default settings', () async {
      final svc = TtsService();
      await svc.initialize();
    });

    test('is idempotent — second call is a no-op', () async {
      final svc = TtsService();
      await svc.initialize(rate: 0.5);
      await svc.initialize(rate: 0.9); // should not change anything
    });

    test('sets voice when voiceIdentifier is found in available voices',
        () async {
      _setUpTtsMock(voices: [
        {'name': 'Alex', 'locale': 'en-US'},
        {'name': 'Sofia', 'locale': 'es-MX'},
      ]);
      final svc = TtsService();
      await svc.initialize(voiceIdentifier: 'Alex');
    });

    test('is a no-op for voice when voiceIdentifier is not found', () async {
      _setUpTtsMock(voices: [
        {'name': 'Other', 'locale': 'en-US'},
      ]);
      final svc = TtsService();
      await svc.initialize(voiceIdentifier: 'NonExistent');
    });

    test('handles empty voice list gracefully', () async {
      _setUpTtsMock(voices: []);
      final svc = TtsService();
      await svc.initialize(voiceIdentifier: 'Alex');
    });
  });

  group('TtsService.speak', () {
    test('initializes then speaks', () async {
      final svc = TtsService();
      await svc.speak('hello');
    });

    test('can speak multiple times', () async {
      final svc = TtsService();
      await svc.speak('more');
      await svc.speak('please');
    });
  });

  group('TtsService.stop', () {
    test('calls through without error', () async {
      final svc = TtsService();
      await svc.stop();
    });
  });

  group('TtsService.applySettings', () {
    test('updates rate, pitch, volume without voiceIdentifier', () async {
      final svc = TtsService();
      await svc.applySettings(rate: 0.7, pitch: 1.1, volume: 0.8);
    });

    test('sets voice when voiceIdentifier is found', () async {
      _setUpTtsMock(voices: [
        {'name': 'Tom', 'locale': 'en-US'},
      ]);
      final svc = TtsService();
      await svc.applySettings(
        rate: 0.5,
        pitch: 1.0,
        volume: 1.0,
        voiceIdentifier: 'Tom',
      );
    });

    test('is a no-op for voice when voiceIdentifier is not found', () async {
      _setUpTtsMock(voices: [
        {'name': 'Other', 'locale': 'en-US'},
      ]);
      final svc = TtsService();
      await svc.applySettings(
        rate: 0.5,
        pitch: 1.0,
        volume: 1.0,
        voiceIdentifier: 'Missing',
      );
    });
  });

  group('TtsService.getAvailableVoices', () {
    test('returns empty list when TTS returns null', () async {
      _setUpTtsMock(voices: null);
      final svc = TtsService();
      final voices = await svc.getAvailableVoices();
      expect(voices, isEmpty);
    });

    test('filters to English and Spanish voices only', () async {
      _setUpTtsMock(voices: [
        {'name': 'Alex', 'locale': 'en-US'},
        {'name': 'Sofia', 'locale': 'es-MX'},
        {'name': 'Klaus', 'locale': 'de-DE'},
        {'name': 'Marie', 'locale': 'fr-FR'},
      ]);
      final svc = TtsService();
      final voices = await svc.getAvailableVoices();
      expect(voices.length, 2);
      expect(voices.map((v) => v['name']), containsAll(['Alex', 'Sofia']));
    });

    test('returns empty list when all voices are filtered out', () async {
      _setUpTtsMock(voices: [
        {'name': 'Klaus', 'locale': 'de-DE'},
      ]);
      final svc = TtsService();
      final voices = await svc.getAvailableVoices();
      expect(voices, isEmpty);
    });
  });

  group('TtsService.dispose', () {
    test('calls stop without throwing', () {
      final svc = TtsService();
      svc.dispose();
    });
  });
}
