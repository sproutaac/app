import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:sprout_aac/services/symbol_service.dart';

// ── path_provider mock ───────────────────────────────────────────────────────

class MockPathProviderPlatform extends Fake
    with MockPlatformInterfaceMixin
    implements PathProviderPlatform {
  final Directory dir;
  MockPathProviderPlatform(this.dir);

  @override
  Future<String?> getApplicationDocumentsPath() async => dir.path;
}

// ── Dio mock ──────────────────────────────────────────────────────────────────

class MockDio extends Mock implements Dio {}

Response<dynamic> _okResponse(dynamic data) => Response(
      data: data,
      statusCode: 200,
      requestOptions: RequestOptions(path: ''),
    );

void main() {
  late Directory tempDir;
  late MockDio mockDio;
  late SymbolService service;

  setUpAll(() {
    registerFallbackValue(RequestOptions(path: ''));
    registerFallbackValue(Options());
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('symbol_test_');
    PathProviderPlatform.instance = MockPathProviderPlatform(tempDir);
    mockDio = MockDio();
    service = SymbolService(dio: mockDio);
    await service.initialize();
  });

  tearDown(() async {
    await tempDir.delete(recursive: true);
  });

  // ── search() ─────────────────────────────────────────────────────────────

  group('search()', () {
    test('returns results from ARASAAC on 200', () async {
      when(() => mockDio.get(
            any(),
            options: any(named: 'options'),
          )).thenAnswer((_) async => _okResponse([
            {
              '_id': 1,
              'keywords': [
                {'keyword': 'cat'}
              ]
            },
          ]));

      final results = await service.search('cat');
      expect(results.length, 1);
      expect(results.first.label, 'cat');
      expect(results.first.imageUrl,
          'https://static.arasaac.org/pictograms/1/1_500.png');
      expect(results.first.source, 'arasaac');
    });

    test('returns empty list on non-200 response', () async {
      when(() => mockDio.get(any(), options: any(named: 'options')))
          .thenAnswer((_) async => Response(
                data: [],
                statusCode: 404,
                requestOptions: RequestOptions(path: ''),
              ));

      final results = await service.search('cat');
      expect(results, isEmpty);
    });

    test('falls back to local cache on network error', () async {
      // Pre-populate cache via a successful search
      when(() => mockDio.get(any(), options: any(named: 'options')))
          .thenAnswer((_) async => _okResponse([
                {
                  '_id': 2,
                  'keywords': [
                    {'keyword': 'dog'}
                  ]
                },
              ]));
      await service.search('dog'); // populates cache

      // Now simulate network failure
      when(() => mockDio.get(any(), options: any(named: 'options')))
          .thenThrow(DioException(
              type: DioExceptionType.connectionError,
              requestOptions: RequestOptions(path: '')));

      final results = await service.search('dog');
      expect(results.length, 1);
      expect(results.first.label, 'dog');
    });

    test('returns empty on network error with empty cache', () async {
      when(() => mockDio.get(any(), options: any(named: 'options')))
          .thenThrow(DioException(
              type: DioExceptionType.connectionError,
              requestOptions: RequestOptions(path: '')));

      final results = await service.search('unknown');
      expect(results, isEmpty);
    });

    test('caches results to disk after successful fetch', () async {
      when(() => mockDio.get(any(), options: any(named: 'options')))
          .thenAnswer((_) async => _okResponse([
                {
                  '_id': 5,
                  'keywords': [
                    {'keyword': 'fish'}
                  ]
                },
              ]));

      await service.search('fish');

      final indexFile =
          File('${tempDir.path}/symbol_cache/index.json');
      expect(await indexFile.exists(), isTrue);
    });
  });

  // ── getById() ──────────────────────────────────────────────────────────────

  group('getById()', () {
    test('returns cached symbol if already in cache', () async {
      when(() => mockDio.get(any(), options: any(named: 'options')))
          .thenAnswer((_) async => _okResponse([
                {
                  '_id': 7,
                  'keywords': [
                    {'keyword': 'bird'}
                  ]
                },
              ]));
      await service.search('bird'); // loads id 7 into cache

      final result = await service.getById('7');
      expect(result, isNotNull);
      expect(result!.label, 'bird');
    });

    test('constructs symbol from ARASAAC URL when not cached', () async {
      final result = await service.getById('999');
      expect(result, isNotNull);
      expect(result!.id, '999');
      expect(result.imageUrl,
          'https://static.arasaac.org/pictograms/999/999_500.png');
    });
  });

  // ── cacheSymbolLocally() ──────────────────────────────────────────────────

  group('cacheSymbolLocally()', () {
    test('returns symbol unchanged if already has a valid local path',
        () async {
      final localFile =
          File('${tempDir.path}/existing.png')..writeAsBytesSync([1, 2, 3]);
      const sym = AacSymbol(
        id: '10',
        label: 'x',
        imageUrl: 'https://example.com/x.png',
        localPath: '',
        source: 'arasaac',
      );
      // localPath is set but empty string — file won't exist, so download path
      // is exercised. Use a real path to test the early-return path.
      final symWithPath = AacSymbol(
        id: '10',
        label: 'x',
        imageUrl: 'https://example.com/x.png',
        localPath: localFile.path,
        source: 'arasaac',
      );

      final result = await service.cacheSymbolLocally(symWithPath);
      expect(result, isNotNull);
      expect(result!.localPath, localFile.path);
    });

    test('downloads and returns updated symbol on success', () async {
      when(() => mockDio.download(any(), any())).thenAnswer((_) async =>
          Response(
              data: null,
              statusCode: 200,
              requestOptions: RequestOptions(path: '')));

      const sym = AacSymbol(
        id: '11',
        label: 'y',
        imageUrl: 'https://example.com/y.png',
        source: 'arasaac',
      );

      final result = await service.cacheSymbolLocally(sym);
      expect(result, isNotNull);
    });

    test('returns original symbol on download failure', () async {
      when(() => mockDio.download(any(), any()))
          .thenThrow(Exception('network error'));

      const sym = AacSymbol(
        id: '12',
        label: 'z',
        imageUrl: 'https://example.com/z.png',
        source: 'arasaac',
      );

      final result = await service.cacheSymbolLocally(sym);
      expect(result, isNotNull);
      expect(result!.localPath, isNull);
    });
  });
}
