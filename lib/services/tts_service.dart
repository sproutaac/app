// ============================================================
// tts_service.dart — Text-to-speech, offline-first
// Uses platform native TTS (free, no API key).
// Voice settings are per-child profile.
// ============================================================

import 'dart:io';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class TtsService {
  final FlutterTts _tts = FlutterTts();
  bool _isInitialized = false;

  Future<void> initialize({
    double rate = 0.5,
    double pitch = 1.0,
    double volume = 1.0,
    String? voiceIdentifier,
  }) async {
    if (_isInitialized) return;

    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(rate);
    await _tts.setPitch(pitch);
    await _tts.setVolume(volume);

    // Android-specific: prefer better quality engine
    if (Platform.isAndroid) {
      await _tts.setQueueMode(1); // flush queue on new speak
    }

    if (voiceIdentifier != null) {
      final voices = await getAvailableVoices();
      final match = voices.firstWhere(
        (v) => v['name'] == voiceIdentifier,
        orElse: () => {},
      );
      if (match.isNotEmpty) {
        await _tts.setVoice(match);
      }
    }

    _tts.setCompletionHandler(() {});
    _tts.setErrorHandler((msg) {
      // Silently handle errors — never crash on TTS failure
    });

    _isInitialized = true;
  }

  /// Speak a word or phrase. Interrupts any current speech.
  Future<void> speak(String text) async {
    if (!_isInitialized) await initialize();
    await _tts.stop();
    await _tts.speak(text);
  }

  /// Stop any current speech.
  Future<void> stop() async => _tts.stop();

  /// Apply new voice settings (called when child profile changes).
  Future<void> applySettings({
    required double rate,
    required double pitch,
    required double volume,
    String? voiceIdentifier,
  }) async {
    await _tts.setSpeechRate(rate);
    await _tts.setPitch(pitch);
    await _tts.setVolume(volume);

    if (voiceIdentifier != null) {
      final voices = await getAvailableVoices();
      final match = voices.firstWhere(
        (v) => v['name'] == voiceIdentifier,
        orElse: () => {},
      );
      if (match.isNotEmpty) {
        await _tts.setVoice(match);
      }
    }
  }

  Future<List<Map<String, String>>> getAvailableVoices() async {
    final raw = await _tts.getVoices;
    if (raw == null) return [];
    return (raw as List)
        .map((v) => Map<String, String>.from(v as Map))
        .where((v) =>
            v['locale']?.startsWith('en') == true ||
            v['locale']?.startsWith('es') == true)
        .toList();
  }

  void dispose() {
    _tts.stop();
  }
}

// Riverpod provider — singleton for the app lifetime
final ttsServiceProvider = Provider<TtsService>((ref) {
  final service = TtsService();
  ref.onDispose(service.dispose);
  return service;
});
