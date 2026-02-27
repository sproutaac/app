// ============================================================
// symbol_service.dart — OpenSymbols integration
// Fetches and caches symbols locally.
// Core symbol set bundled at install; extras fetched on demand.
// ============================================================

import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'dart:io';

class AacSymbol {
  final String id;
  final String label;
  final String imageUrl;
  final String? localPath;
  final String source; // 'opensymbols' | 'bundled' | 'custom'

  const AacSymbol({
    required this.id,
    required this.label,
    required this.imageUrl,
    this.localPath,
    required this.source,
  });

  bool get isAvailableOffline => localPath != null;

  factory AacSymbol.fromOpenSymbolsJson(Map<String, dynamic> json) {
    return AacSymbol(
      id: json['id'].toString(),
      label: json['name'] as String,
      imageUrl: json['image_url'] as String,
      source: 'opensymbols',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'imageUrl': imageUrl,
        'localPath': localPath,
        'source': source,
      };

  factory AacSymbol.fromJson(Map<String, dynamic> json) => AacSymbol(
        id: json['id'] as String,
        label: json['label'] as String,
        imageUrl: json['imageUrl'] as String,
        localPath: json['localPath'] as String?,
        source: json['source'] as String,
      );
}

class SymbolService {
  final Dio _dio;
  // Local cache: symbolId -> AacSymbol
  final Map<String, AacSymbol> _cache = {};
  Directory? _cacheDir;

  static const String _openSymbolsBase =
      'https://opensymbols.org/api/v1/symbols';

  SymbolService({Dio? dio}) : _dio = dio ?? Dio();

  Future<void> initialize() async {
    final appDir = await getApplicationDocumentsDirectory();
    _cacheDir = Directory(p.join(appDir.path, 'symbol_cache'));
    if (!await _cacheDir!.exists()) {
      await _cacheDir!.create(recursive: true);
    }
    await _loadCacheIndex();
  }

  /// Search OpenSymbols API. Falls back to local cache if offline.
  Future<List<AacSymbol>> search(String query) async {
    // First check local cache for matches
    final localMatches = _cache.values
        .where((s) =>
            s.label.toLowerCase().contains(query.toLowerCase()))
        .toList();

    try {
      final response = await _dio.get(
        _openSymbolsBase,
        queryParameters: {'q': query, 'locale': 'en'},
        options: Options(
          sendTimeout: const Duration(seconds: 5),
          receiveTimeout: const Duration(seconds: 5),
        ),
      );

      if (response.statusCode == 200) {
        final data = response.data as List;
        final remoteSymbols =
            data.map((j) => AacSymbol.fromOpenSymbolsJson(j)).toList();

        // Cache the results
        for (final sym in remoteSymbols) {
          _cache[sym.id] = sym;
        }
        await _saveCacheIndex();
        return remoteSymbols;
      }
    } catch (_) {
      // Network unavailable — return local matches only
    }

    return localMatches;
  }

  /// Get a symbol by ID, from cache or network.
  Future<AacSymbol?> getById(String id) async {
    if (_cache.containsKey(id)) return _cache[id];

    try {
      final response = await _dio.get('$_openSymbolsBase/$id');
      if (response.statusCode == 200) {
        final sym = AacSymbol.fromOpenSymbolsJson(response.data);
        _cache[id] = sym;
        return sym;
      }
    } catch (_) {}

    return null;
  }

  /// Download and cache a symbol image locally for offline use.
  Future<AacSymbol?> cacheSymbolLocally(AacSymbol symbol) async {
    if (_cacheDir == null) await initialize();

    // Already cached
    if (symbol.localPath != null) {
      final file = File(symbol.localPath!);
      if (await file.exists()) return symbol;
    }

    try {
      final ext = symbol.imageUrl.endsWith('.png') ? 'png' : 'svg';
      final localPath =
          p.join(_cacheDir!.path, '${symbol.id}.$ext');

      await _dio.download(symbol.imageUrl, localPath);

      final updated = AacSymbol(
        id: symbol.id,
        label: symbol.label,
        imageUrl: symbol.imageUrl,
        localPath: localPath,
        source: symbol.source,
      );
      _cache[symbol.id] = updated;
      await _saveCacheIndex();
      return updated;
    } catch (_) {
      return symbol; // Return without local path if download fails
    }
  }

  Future<void> _loadCacheIndex() async {
    final indexFile = File(p.join(_cacheDir!.path, 'index.json'));
    if (!await indexFile.exists()) return;

    try {
      final content = await indexFile.readAsString();
      final data = jsonDecode(content) as Map<String, dynamic>;
      data.forEach((key, value) {
        _cache[key] =
            AacSymbol.fromJson(value as Map<String, dynamic>);
      });
    } catch (_) {}
  }

  Future<void> _saveCacheIndex() async {
    if (_cacheDir == null) return;
    final indexFile = File(p.join(_cacheDir!.path, 'index.json'));
    final data = {
      for (final entry in _cache.entries)
        entry.key: entry.value.toJson()
    };
    await indexFile.writeAsString(jsonEncode(data));
  }
}

final symbolServiceProvider = Provider<SymbolService>((ref) {
  final service = SymbolService();
  service.initialize();
  return service;
});
