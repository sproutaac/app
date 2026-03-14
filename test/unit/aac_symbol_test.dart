import 'package:flutter_test/flutter_test.dart';
import 'package:sprout_aac/services/symbol_service.dart';

void main() {
  group('AacSymbol', () {
    test('fromArasaacJson parses id, first keyword, and image URL', () {
      final json = {
        '_id': 7114,
        'keywords': [
          {'keyword': 'cat', 'type': 1, 'plural': 'cats'},
          {'keyword': 'kitty', 'type': 1, 'plural': 'kitties'},
        ],
      };

      final symbol = AacSymbol.fromArasaacJson(json);

      expect(symbol.id, '7114');
      expect(symbol.label, 'cat');
      expect(symbol.imageUrl,
          'https://static.arasaac.org/pictograms/7114/7114_500.png');
      expect(symbol.source, 'arasaac');
      expect(symbol.localPath, isNull);
    });

    test('fromArasaacJson uses id as label when keywords is empty', () {
      final json = {
        '_id': 999,
        'keywords': <dynamic>[],
      };

      final symbol = AacSymbol.fromArasaacJson(json);

      expect(symbol.id, '999');
      expect(symbol.label, '999');
    });

    test('toJson / fromJson round-trips correctly', () {
      const original = AacSymbol(
        id: '42',
        label: 'dog',
        imageUrl: 'https://example.com/dog.png',
        localPath: '/cache/42.png',
        source: 'arasaac',
      );

      final json = original.toJson();
      final restored = AacSymbol.fromJson(json);

      expect(restored.id, original.id);
      expect(restored.label, original.label);
      expect(restored.imageUrl, original.imageUrl);
      expect(restored.localPath, original.localPath);
      expect(restored.source, original.source);
    });

    test('toJson / fromJson round-trips with null localPath', () {
      const original = AacSymbol(
        id: '1',
        label: 'more',
        imageUrl: 'https://example.com/1.png',
        source: 'arasaac',
      );

      final restored = AacSymbol.fromJson(original.toJson());
      expect(restored.localPath, isNull);
    });

    test('isAvailableOffline is true when localPath is set', () {
      const sym = AacSymbol(
          id: '1', label: 'x', imageUrl: 'u', localPath: '/p', source: 's');
      expect(sym.isAvailableOffline, isTrue);
    });

    test('isAvailableOffline is false when localPath is null', () {
      const sym =
          AacSymbol(id: '1', label: 'x', imageUrl: 'u', source: 's');
      expect(sym.isAvailableOffline, isFalse);
    });
  });
}
