import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

const _workerApiBase = String.fromEnvironment(
  'COMPARADOR_API_BASE_URL',
  defaultValue: '',
);

const _vtexStores = <_Store>[
  _Store('Jumbo', 'www.jumbo.com.ar'),
  _Store('Disco', 'www.disco.com.ar'),
  _Store('Vea', 'www.vea.com.ar'),
  _Store('Carrefour', 'www.carrefour.com.ar'),
  _Store('DIA', 'diaonline.supermercadosdia.com.ar'),
  _Store('ChangoMás', 'www.masonline.com.ar'),
];

class StoreStatus {
  const StoreStatus({
    required this.store,
    required this.ok,
    this.status,
    this.error,
  });

  final String store;
  final bool ok;
  final int? status;
  final String? error;

  factory StoreStatus.fromJson(Map<String, dynamic> json) => StoreStatus(
        store: json['store']?.toString() ?? 'Comercio',
        ok: json['ok'] == true,
        status: (json['status'] as num?)?.toInt(),
        error: json['error']?.toString(),
      );
}

class StoreOffer {
  const StoreOffer({
    required this.store,
    required this.name,
    required this.price,
    this.ean,
    this.brand,
    this.variant,
    this.listPrice,
    this.stock,
    this.image,
    this.url,
    this.priceType,
    this.branchLabel,
    this.promotions = const [],
  });

  final String store;
  final String name;
  final double price;
  final String? ean;
  final String? brand;
  final String? variant;
  final double? listPrice;
  final int? stock;
  final String? image;
  final String? url;
  final String? priceType;
  final String? branchLabel;
  final List<Map<String, dynamic>> promotions;

  Map<String, dynamic> toJson() => {
        'store': store,
        'name': name,
        'price': price,
        'ean': ean,
        'brand': brand,
        'variant': variant,
        'listPrice': listPrice,
        'stock': stock,
        'image': image,
        'url': url,
        'priceType': priceType,
        'branchLabel': branchLabel,
        'promotions': promotions,
      };

  factory StoreOffer.fromJson(Map<String, dynamic> json) => StoreOffer(
        store: json['store']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
        price: _number(json['price']) ?? 0,
        ean: json['ean']?.toString(),
        brand: json['brand']?.toString(),
        variant: json['variant']?.toString(),
        listPrice: _number(json['listPrice']),
        stock: (json['stock'] as num?)?.toInt(),
        image: json['image']?.toString(),
        url: json['url']?.toString(),
        priceType: json['priceType']?.toString(),
        branchLabel: json['branchLabel']?.toString(),
        promotions: (json['promotions'] as List<dynamic>? ?? [])
            .whereType<Map<String, dynamic>>()
            .toList(),
      );
}

class CatalogProduct {
  const CatalogProduct({
    required this.name,
    required this.offers,
    this.ean,
    this.brand,
    this.comparableByEan = false,
  });

  final String name;
  final String? ean;
  final String? brand;
  final bool comparableByEan;
  final List<StoreOffer> offers;

  factory CatalogProduct.fromJson(Map<String, dynamic> json) {
    final offers = (json['offers'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(StoreOffer.fromJson)
        .toList();
    return CatalogProduct(
      name: json['name']?.toString() ?? 'Producto sin nombre',
      ean: json['ean']?.toString(),
      brand: json['brand']?.toString(),
      comparableByEan: json['comparableByEan'] == true,
      offers: offers,
    );
  }
}

class CatalogSearchResult {
  const CatalogSearchResult({
    required this.query,
    required this.generatedAt,
    required this.products,
    required this.stores,
  });

  final String query;
  final DateTime generatedAt;
  final List<CatalogProduct> products;
  final List<StoreStatus> stores;

  factory CatalogSearchResult.fromJson(Map<String, dynamic> json) {
    return CatalogSearchResult(
      query: json['query']?.toString() ?? '',
      generatedAt: DateTime.tryParse(json['generatedAt']?.toString() ?? '') ??
          DateTime.now(),
      products: (json['products'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(CatalogProduct.fromJson)
          .toList(),
      stores: (json['stores'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(StoreStatus.fromJson)
          .toList(),
    );
  }
}

class _Store {
  const _Store(this.name, this.domain);
  final String name;
  final String domain;
}

class _StoreSearch {
  const _StoreSearch(this.status, this.offers);
  final StoreStatus status;
  final List<StoreOffer> offers;
}

class CatalogService {
  CatalogService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<CatalogSearchResult> search(String rawQuery, {int limit = 50}) async {
    final query = rawQuery.trim();
    if (query.length < 2) {
      throw Exception('Escribí al menos dos caracteres para buscar.');
    }

    if (kIsWeb) {
      return _searchThroughWorker(query, limit);
    }

    final vtexResults = await Future.wait(
      _vtexStores.map((store) => _searchVtex(store, query, limit)),
    );

    var cotoQuery = query;
    if (RegExp(r'^\d{8,14}$').hasMatch(query)) {
      for (final result in vtexResults) {
        final match = result.offers.where((offer) => offer.ean == query);
        if (match.isNotEmpty) {
          cotoQuery = match.first.name;
          break;
        }
      }
    }

    final cotoResult = await _searchCoto(cotoQuery, limit);
    final results = [...vtexResults, cotoResult];

    // En búsquedas por texto, exigir que el primer término del producto
    // coincida con el primero buscado. Las búsquedas por EAN son exactas.
    final isBarcode = RegExp(r'^\d{8,14}  }

  Future<CatalogSearchResult> _searchThroughWorker(
    String query,
    int limit,
  ) async {
    final base = _workerApiBase.trim().replaceFirst(RegExp(r'/+$'), '');
    if (base.isEmpty) {
      throw Exception(
        'La búsqueda web necesita configurar el servicio gratuito de catálogos. '
        'En Android la consulta se realiza directamente a los supermercados.',
      );
    }
    final uri = Uri.parse('$base/search').replace(
      queryParameters: {'q': query, 'limit': '$limit'},
    );
    final response = await _client.get(uri);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('El servicio de búsqueda respondió HTTP ${response.statusCode}.');
    }
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    return CatalogSearchResult.fromJson(decoded);
  }

  Future<_StoreSearch> _searchVtex(
    _Store store,
    String query,
    int limit,
  ) async {
    try {
      final decodedProducts = <Map<String, dynamic>>[];
      var lastStatus = 200;

      // VTEX pagina los resultados en bloques. Seguimos consultando hasta
      // recibir una página incompleta o vacía, con un límite de seguridad.
      for (var offset = 0; offset < limit * 100; offset += limit) {
        final uri = Uri.https(
          store.domain,
          '/api/catalog_system/pub/products/search',
          {
            'ft': query,
            '_from': '$offset',
            '_to': '${offset + limit - 1}',
          },
        );
        final response = await _client.get(
          uri,
          headers: {
            'accept': 'application/json',
            'user-agent': 'ComparadorInteligente/0.1',
          },
        );
        lastStatus = response.statusCode;
        if (response.statusCode < 200 || response.statusCode >= 300) {
          return _StoreSearch(
            StoreStatus(
              store: store.name,
              ok: false,
              status: response.statusCode,
              error: 'El catálogo no respondió correctamente.',
            ),
            const [],
          );
        }
        final decoded = jsonDecode(response.body);
        if (decoded is! List) {
          return _StoreSearch(
            StoreStatus(
              store: store.name,
              ok: false,
              status: response.statusCode,
              error: 'El catálogo devolvió un formato inesperado.',
            ),
            const [],
          );
        }
        final pageProducts = decoded.whereType<Map<String, dynamic>>().toList();
        if (pageProducts.isEmpty) break;
        decodedProducts.addAll(pageProducts);
        if (pageProducts.length < limit) break;
      }

      final offers = <StoreOffer>[];
      for (final rawProduct in decodedProducts) {
        final items = rawProduct['items'] as List<dynamic>? ?? [];
        for (final rawItem in items.whereType<Map<String, dynamic>>()) {
          final sellers = rawItem['sellers'] as List<dynamic>? ?? [];
          final candidates = <Map<String, dynamic>>[];
          for (final rawSeller in sellers.whereType<Map<String, dynamic>>()) {
            final offer = rawSeller['commertialOffer'] ??
                rawSeller['commercialOffer'];
            if (offer is Map<String, dynamic> &&
                _number(offer['Price'] ?? offer['price']) != null) {
              candidates.add(offer);
            }
          }
          if (candidates.isEmpty) continue;
          candidates.sort((a, b) =>
              (_number(a['Price'] ?? a['price']) ?? double.infinity)
                  .compareTo(
                _number(b['Price'] ?? b['price']) ?? double.infinity,
              ));
          final offer = candidates.first;
          final images = rawItem['images'] as List<dynamic>? ?? [];
          final image = images.isNotEmpty &&
                  images.first is Map<String, dynamic>
              ? (images.first as Map<String, dynamic>)['imageUrl']?.toString()
              : null;
          final link = rawProduct['link']?.toString();
          final productUrl = link == null
              ? null
              : Uri.parse('https://${store.domain}').resolve(link).toString();

          offers.add(StoreOffer(
            store: store.name,
            name: rawProduct['productName']?.toString() ??
                rawItem['name']?.toString() ??
                'Producto sin nombre',
            brand: rawProduct['brand']?.toString(),
            variant: rawItem['name']?.toString(),
            ean: rawItem['ean']?.toString(),
            price: _number(offer['Price'] ?? offer['price'])!,
            listPrice: _number(offer['ListPrice'] ?? offer['listPrice']),
            stock: (offer['AvailableQuantity'] ??
                    offer['availableQuantity']) is num
                ? ((offer['AvailableQuantity'] ??
                        offer['availableQuantity']) as num)
                    .toInt()
                : null,
            image: image,
            url: productUrl,
            priceType: 'online_default_channel',
            promotions: (offer['Teasers'] as List<dynamic>? ?? [])
                .whereType<Map<String, dynamic>>()
                .map((teaser) => {
                      'text': teaser['name']?.toString() ??
                          teaser['teaserName']?.toString() ??
                          'Promoción publicada por el supermercado',
                    })
                .toList(),
          ));
        }
      }
      return _StoreSearch(
        StoreStatus(
          store: store.name,
          ok: true,
          status: lastStatus,
        ),
        offers,
      );
    } catch (error) {
      return _StoreSearch(
        StoreStatus(
          store: store.name,
          ok: false,
          error: error.toString(),
        ),
        const [],
      );
    }
  }

  Future<_StoreSearch> _searchCoto(String query, int limit) async {
    try {
      final allRecords = <Map<String, dynamic>>[];
      var lastStatus = 200;

      // Coto utiliza paginación Endeca (No + Nrpp). Recuperamos las páginas
      // disponibles hasta que el buscador devuelve menos resultados.
      for (var offset = 0; offset < limit * 100; offset += limit) {
        final uri = Uri.https(
          'www.cotodigital.com.ar',
          '/sitios/cdigi/categoria',
          {
            '_dyncharset': 'utf8',
            'Dy': '1',
            'No': '$offset',
            'Nrpp': '$limit',
            'Ntt': query,
            'idSucursal': '200',
            'format': 'json',
          },
        );
        final response = await _client.get(
          uri,
          headers: {
            'accept': 'application/json',
            'referer': 'https://www.cotodigital.com.ar/',
            'user-agent': 'Mozilla/5.0 ComparadorInteligente/0.1',
          },
        );
        lastStatus = response.statusCode;
        if (response.statusCode < 200 || response.statusCode >= 300) {
          return _StoreSearch(
            StoreStatus(
              store: 'Coto',
              ok: false,
              status: response.statusCode,
              error: 'El catálogo no respondió correctamente.',
            ),
            const [],
          );
        }

        final decoded = jsonDecode(response.body) as Map<String, dynamic>;
        final contents = decoded['contents'] as List<dynamic>? ?? [];
        final main = contents.isNotEmpty && contents.first is Map<String, dynamic>
            ? (contents.first as Map<String, dynamic>)['Main'] as List<dynamic>? ?? []
            : [];
        final pageRecords = main.length > 2 && main[2] is Map<String, dynamic>
            ? ((main[2] as Map<String, dynamic>)['contents'] as List<dynamic>? ?? [])
                .whereType<Map<String, dynamic>>()
                .expand((item) => (item['records'] as List<dynamic>? ?? []))
                .whereType<Map<String, dynamic>>()
                .toList()
            : <Map<String, dynamic>>[];

        if (pageRecords.isEmpty) break;
        allRecords.addAll(pageRecords);
        if (pageRecords.length < limit) break;
      }

      final offers = <StoreOffer>[];
      for (final rawRecord in allRecords) {
        final recordRows = rawRecord['records'] as List<dynamic>? ?? [];
        if (recordRows.isEmpty || recordRows.first is! Map<String, dynamic>) {
          continue;
        }
        final record = recordRows.first as Map<String, dynamic>;
        final attributes =
            record['attributes'] as Map<String, dynamic>? ?? {};
        String? value(String key) {
          final values = attributes[key] as List<dynamic>? ?? [];
          return values.isEmpty ? null : values.first?.toString();
        }

        final price = _parseLocalizedPrice(value('sku.activePrice'));
        if (price == null) continue;
        final state = record['detailsAction'] is Map<String, dynamic>
            ? (record['detailsAction'] as Map<String, dynamic>)['recordState']
                ?.toString()
            : null;
        final productUrl = state == null
            ? null
            : 'https://www.cotodigital.com.ar/sitios/cdigi/productos${state.split('?').first}';
        final promotions = <Map<String, dynamic>>[];
        try {
          final rawPromotions = value('product.dtoDescuentos');
          if (rawPromotions != null) {
            final decodedPromotions = jsonDecode(rawPromotions) as List<dynamic>;
            for (final promotion in decodedPromotions.whereType<Map<String, dynamic>>()) {
              promotions.add({
                'text': promotion['textoDescuento'],
                'price': _parseLocalizedPrice(
                  promotion['precioDescuento']?.toString().replaceAll('c/u', ''),
                ),
                'restriction': (promotion['imagenDescuento']?.toString() ?? '')
                        .contains('comunidad')
                    ? 'Exclusivo Comunidad Coto'
                    : null,
              });
            }
          }
        } catch (_) {
          // Keep the regular price when promotional metadata is malformed.
        }

        offers.add(StoreOffer(
          store: 'Coto',
          name: value('sku.displayName') ?? 'Producto sin nombre',
          ean: value('product.eanPrincipal'),
          price: price,
          listPrice: _parseLocalizedPrice(value('sku.listPrice')),
          image: value('product.largeImage.url'),
          url: productUrl,
          priceType: 'online_branch_200',
          branchLabel: 'Sucursal de referencia 200',
          promotions: promotions,
        ));
      }

      return _StoreSearch(
        StoreStatus(store: 'Coto', ok: true, status: lastStatus),
        offers,
      );
    } catch (error) {
      return _StoreSearch(
        StoreStatus(store: 'Coto', ok: false, error: error.toString()),
        const [],
      );
    }
  }

  CatalogSearchResult _groupResults(
    String query,
    List<_StoreSearch> results,
  ) {
    final grouped = <String, List<StoreOffer>>{};
    for (final offer in results.expand((result) => result.offers)) {
      final key = offer.ean != null && offer.ean!.isNotEmpty
          ? 'ean:${offer.ean}'
          : 'unique:${offer.store}:${offer.name}';
      grouped.putIfAbsent(key, () => []).add(offer);
    }

    final products = grouped.values.map((offers) {
      offers.sort((a, b) => a.price.compareTo(b.price));
      final first = offers.first;
      return CatalogProduct(
        name: first.name,
        ean: first.ean,
        brand: first.brand,
        comparableByEan: first.ean != null && first.ean!.isNotEmpty,
        offers: offers,
      );
    }).toList()
      ..sort((a, b) => a.offers.first.price.compareTo(b.offers.first.price));

    return CatalogSearchResult(
      query: query,
      generatedAt: DateTime.now(),
      products: products,
      stores: results.map((result) => result.status).toList(),
    );
  }

  void close() => _client.close();
}

String _normalizeSearchText(String value) {
  return value
      .toLowerCase()
      .replaceAll('á', 'a')
      .replaceAll('é', 'e')
      .replaceAll('í', 'i')
      .replaceAll('ó', 'o')
      .replaceAll('ú', 'u')
      .replaceAll('ü', 'u')
      .replaceAll(RegExp(r'[^a-z0-9ñ]+'), ' ')
      .trim();
}

bool _firstWordMatches(String productName, String firstTerm) {
  final normalizedName = _normalizeSearchText(productName);
  if (normalizedName.isEmpty || firstTerm.isEmpty) return false;
  return normalizedName.split(' ').first == firstTerm;
}

double? _number(dynamic value) {
  if (value is num) return value.toDouble() > 0 ? value.toDouble() : null;
  return _parseLocalizedPrice(value?.toString());
}

double? _parseLocalizedPrice(String? value) {
  if (value == null) return null;
  var raw = value.trim().replaceAll(RegExp(r'[^0-9,.-]'), '');
  if (raw.contains(',') && raw.contains('.')) {
    raw = raw.replaceAll('.', '').replaceFirst(',', '.');
  } else if (raw.contains(',')) {
    raw = raw.replaceFirst(',', '.');
  } else if (RegExp(r'^\d{1,3}(\.\d{3})+$').hasMatch(raw)) {
    raw = raw.replaceAll('.', '');
  }
  final parsed = double.tryParse(raw);
  return parsed != null && parsed > 0 ? parsed : null;
}
).hasMatch(query);
    final firstTerm = _normalizeSearchText(query).split(' ').first;
    final filteredResults = isBarcode
        ? results
        : results
            .map((result) => _StoreSearch(
                  result.status,
                  result.offers
                      .where((offer) => _firstWordMatches(offer.name, firstTerm))
                      .toList(),
                ))
            .toList();
    return _groupResults(query, filteredResults);
  }

  Future<CatalogSearchResult> _searchThroughWorker(
    String query,
    int limit,
  ) async {
    final base = _workerApiBase.trim().replaceFirst(RegExp(r'/+$'), '');
    if (base.isEmpty) {
      throw Exception(
        'La búsqueda web necesita configurar el servicio gratuito de catálogos. '
        'En Android la consulta se realiza directamente a los supermercados.',
      );
    }
    final uri = Uri.parse('$base/search').replace(
      queryParameters: {'q': query, 'limit': '$limit'},
    );
    final response = await _client.get(uri);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('El servicio de búsqueda respondió HTTP ${response.statusCode}.');
    }
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    return CatalogSearchResult.fromJson(decoded);
  }

  Future<_StoreSearch> _searchVtex(
    _Store store,
    String query,
    int limit,
  ) async {
    final uri = Uri.https(
      store.domain,
      '/api/catalog_system/pub/products/search',
      {
        'ft': query,
        '_from': '0',
        '_to': '${limit - 1}',
      },
    );
    try {
      final response = await _client.get(
        uri,
        headers: {
          'accept': 'application/json',
          'user-agent': 'ComparadorInteligente/0.1',
        },
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return _StoreSearch(
          StoreStatus(
            store: store.name,
            ok: false,
            status: response.statusCode,
            error: 'El catálogo no respondió correctamente.',
          ),
          const [],
        );
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! List) {
        return _StoreSearch(
          StoreStatus(
            store: store.name,
            ok: false,
            status: response.statusCode,
            error: 'El catálogo devolvió un formato inesperado.',
          ),
          const [],
        );
      }

      final offers = <StoreOffer>[];
      for (final rawProduct in decoded.whereType<Map<String, dynamic>>()) {
        final items = rawProduct['items'] as List<dynamic>? ?? [];
        for (final rawItem in items.whereType<Map<String, dynamic>>()) {
          final sellers = rawItem['sellers'] as List<dynamic>? ?? [];
          final candidates = <Map<String, dynamic>>[];
          for (final rawSeller in sellers.whereType<Map<String, dynamic>>()) {
            final offer = rawSeller['commertialOffer'] ??
                rawSeller['commercialOffer'];
            if (offer is Map<String, dynamic> &&
                _number(offer['Price'] ?? offer['price']) != null) {
              candidates.add(offer);
            }
          }
          if (candidates.isEmpty) continue;
          candidates.sort((a, b) =>
              (_number(a['Price'] ?? a['price']) ?? double.infinity)
                  .compareTo(
                _number(b['Price'] ?? b['price']) ?? double.infinity,
              ));
          final offer = candidates.first;
          final images = rawItem['images'] as List<dynamic>? ?? [];
          final image = images.isNotEmpty &&
                  images.first is Map<String, dynamic>
              ? (images.first as Map<String, dynamic>)['imageUrl']?.toString()
              : null;
          final link = rawProduct['link']?.toString();
          final productUrl = link == null
              ? null
              : Uri.parse('https://${store.domain}').resolve(link).toString();

          offers.add(StoreOffer(
            store: store.name,
            name: rawProduct['productName']?.toString() ??
                rawItem['name']?.toString() ??
                'Producto sin nombre',
            brand: rawProduct['brand']?.toString(),
            variant: rawItem['name']?.toString(),
            ean: rawItem['ean']?.toString(),
            price: _number(offer['Price'] ?? offer['price'])!,
            listPrice: _number(offer['ListPrice'] ?? offer['listPrice']),
            stock: (offer['AvailableQuantity'] ??
                    offer['availableQuantity']) is num
                ? ((offer['AvailableQuantity'] ??
                        offer['availableQuantity']) as num)
                    .toInt()
                : null,
            image: image,
            url: productUrl,
            priceType: 'online_default_channel',
          ));
        }
      }
      return _StoreSearch(
        StoreStatus(
          store: store.name,
          ok: true,
          status: response.statusCode,
        ),
        offers,
      );
    } catch (error) {
      return _StoreSearch(
        StoreStatus(
          store: store.name,
          ok: false,
          error: error.toString(),
        ),
        const [],
      );
    }
  }

  Future<_StoreSearch> _searchCoto(String query, int limit) async {
    final uri = Uri.https(
      'www.cotodigital.com.ar',
      '/sitios/cdigi/categoria',
      {
        '_dyncharset': 'utf8',
        'Dy': '1',
        'Nrpp': '$limit',
        'Ntt': query,
        'idSucursal': '200',
        'format': 'json',
      },
    );
    try {
      final response = await _client.get(
        uri,
        headers: {
          'accept': 'application/json',
          'referer': 'https://www.cotodigital.com.ar/',
          'user-agent': 'Mozilla/5.0 ComparadorInteligente/0.1',
        },
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return _StoreSearch(
          StoreStatus(
            store: 'Coto',
            ok: false,
            status: response.statusCode,
            error: 'El catálogo no respondió correctamente.',
          ),
          const [],
        );
      }

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final contents = decoded['contents'] as List<dynamic>? ?? [];
      final main = contents.isNotEmpty && contents.first is Map<String, dynamic>
          ? (contents.first as Map<String, dynamic>)['Main'] as List<dynamic>? ??
              []
          : [];
      final records = main.length > 2 &&
              main[2] is Map<String, dynamic>
          ? ((main[2] as Map<String, dynamic>)['contents']
                      as List<dynamic>? ??
                  [])
              .whereType<Map<String, dynamic>>()
              .expand((item) =>
                  (item['records'] as List<dynamic>? ?? []))
              .toList()
          : <dynamic>[];

      final offers = <StoreOffer>[];
      for (final rawRecord in records.whereType<Map<String, dynamic>>()) {
        final recordRows = rawRecord['records'] as List<dynamic>? ?? [];
        if (recordRows.isEmpty || recordRows.first is! Map<String, dynamic>) {
          continue;
        }
        final record = recordRows.first as Map<String, dynamic>;
        final attributes =
            record['attributes'] as Map<String, dynamic>? ?? {};
        String? value(String key) {
          final values = attributes[key] as List<dynamic>? ?? [];
          return values.isEmpty ? null : values.first?.toString();
        }

        final price = _parseLocalizedPrice(value('sku.activePrice'));
        if (price == null) continue;
        final state = record['detailsAction'] is Map<String, dynamic>
            ? (record['detailsAction'] as Map<String, dynamic>)['recordState']
                ?.toString()
            : null;
        final productUrl = state == null
            ? null
            : 'https://www.cotodigital.com.ar/sitios/cdigi/productos${state.split('?').first}';
        final promotions = <Map<String, dynamic>>[];
        try {
          final rawPromotions = value('product.dtoDescuentos');
          if (rawPromotions != null) {
            final decodedPromotions = jsonDecode(rawPromotions) as List<dynamic>;
            for (final promotion in decodedPromotions.whereType<Map<String, dynamic>>()) {
              promotions.add({
                'text': promotion['textoDescuento'],
                'price': _parseLocalizedPrice(
                  promotion['precioDescuento']?.toString().replaceAll('c/u', ''),
                ),
                'restriction': (promotion['imagenDescuento']?.toString() ?? '')
                        .contains('comunidad')
                    ? 'Exclusivo Comunidad Coto'
                    : null,
              });
            }
          }
        } catch (_) {
          // Keep the regular price when promotional metadata is malformed.
        }

        offers.add(StoreOffer(
          store: 'Coto',
          name: value('sku.displayName') ?? 'Producto sin nombre',
          ean: value('product.eanPrincipal'),
          price: price,
          listPrice: _parseLocalizedPrice(value('sku.listPrice')),
          image: value('product.largeImage.url'),
          url: productUrl,
          priceType: 'online_branch_200',
          branchLabel: 'Sucursal de referencia 200',
          promotions: promotions,
        ));
      }

      return _StoreSearch(
        StoreStatus(store: 'Coto', ok: true, status: response.statusCode),
        offers,
      );
    } catch (error) {
      return _StoreSearch(
        StoreStatus(store: 'Coto', ok: false, error: error.toString()),
        const [],
      );
    }
  }

  CatalogSearchResult _groupResults(
    String query,
    List<_StoreSearch> results,
  ) {
    final grouped = <String, List<StoreOffer>>{};
    for (final offer in results.expand((result) => result.offers)) {
      final key = offer.ean != null && offer.ean!.isNotEmpty
          ? 'ean:${offer.ean}'
          : 'unique:${offer.store}:${offer.name}';
      grouped.putIfAbsent(key, () => []).add(offer);
    }

    final products = grouped.values.map((offers) {
      offers.sort((a, b) => a.price.compareTo(b.price));
      final first = offers.first;
      return CatalogProduct(
        name: first.name,
        ean: first.ean,
        brand: first.brand,
        comparableByEan: first.ean != null && first.ean!.isNotEmpty,
        offers: offers,
      );
    }).toList()
      ..sort((a, b) => a.offers.first.price.compareTo(b.offers.first.price));

    return CatalogSearchResult(
      query: query,
      generatedAt: DateTime.now(),
      products: products,
      stores: results.map((result) => result.status).toList(),
    );
  }

  void close() => _client.close();
}

double? _number(dynamic value) {
  if (value is num) return value.toDouble() > 0 ? value.toDouble() : null;
  return _parseLocalizedPrice(value?.toString());
}

double? _parseLocalizedPrice(String? value) {
  if (value == null) return null;
  var raw = value.trim().replaceAll(RegExp(r'[^0-9,.-]'), '');
  if (raw.contains(',') && raw.contains('.')) {
    raw = raw.replaceAll('.', '').replaceFirst(',', '.');
  } else if (raw.contains(',')) {
    raw = raw.replaceFirst(',', '.');
  } else if (RegExp(r'^\d{1,3}(\.\d{3})+$').hasMatch(raw)) {
    raw = raw.replaceAll('.', '');
  }
  final parsed = double.tryParse(raw);
  return parsed != null && parsed > 0 ? parsed : null;
}
