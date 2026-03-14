// ============================================================
// symbol_service.dart — OpenSymbols integration
// Fetches and caches symbols locally.
// Core symbol set bundled at install; extras fetched on demand.
// ============================================================

import 'dart:async';
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

  factory AacSymbol.fromArasaacJson(Map<String, dynamic> json) {
    final id = json['_id'].toString();
    final keywords = json['keywords'] as List<dynamic>;
    final label = keywords.isNotEmpty
        ? keywords[0]['keyword'] as String
        : id;
    return AacSymbol(
      id: id,
      label: label,
      imageUrl: 'https://static.arasaac.org/pictograms/$id/${id}_500.png',
      source: 'arasaac',
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
  // Completer so search() always waits for initialize() to finish,
  // regardless of whether the provider awaited initialize() or not.
  final Completer<void> _ready = Completer<void>();

  // ARASAAC public API — free, no auth required, CC BY-NC-SA licensed
  static const String _arasaacBase =
      'https://api.arasaac.org/api/pictograms';

  static String _arasaacImageUrl(String id) =>
      'https://static.arasaac.org/pictograms/$id/${id}_500.png';

  SymbolService({Dio? dio}) : _dio = dio ?? Dio();

  Future<void> initialize() async {
    final appDir = await getApplicationDocumentsDirectory();
    _cacheDir = Directory(p.join(appDir.path, 'symbol_cache'));
    if (!await _cacheDir!.exists()) {
      await _cacheDir!.create(recursive: true);
    }
    await _loadCacheIndex();
    _ready.complete();
  }

  /// Search ARASAAC API. Falls back to local cache if offline.
  Future<List<AacSymbol>> search(String query) async {
    await _ready.future; // Ensure cache index is loaded before searching
    // First check local cache for matches
    final localMatches = _cache.values
        .where((s) =>
            s.label.toLowerCase().contains(query.toLowerCase()))
        .toList();

    try {
      final encoded = Uri.encodeComponent(query);
      final response = await _dio.get(
        '$_arasaacBase/en/search/$encoded',
        options: Options(
          sendTimeout: const Duration(seconds: 5),
          receiveTimeout: const Duration(seconds: 5),
        ),
      );

      if (response.statusCode == 200) {
        final data = response.data as List;
        final remoteSymbols =
            data.map((j) => AacSymbol.fromArasaacJson(j as Map<String, dynamic>)).toList();

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

  /// Get a symbol by ID, from cache or ARASAAC image URL.
  Future<AacSymbol?> getById(String id) async {
    if (_cache.containsKey(id)) return _cache[id];

    // Construct the symbol directly from the known ARASAAC URL pattern
    final sym = AacSymbol(
      id: id,
      label: id,
      imageUrl: _arasaacImageUrl(id),
      source: 'arasaac',
    );
    _cache[id] = sym;
    return sym;
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
