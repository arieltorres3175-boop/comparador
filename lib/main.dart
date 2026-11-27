import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'services/catalog_service.dart';
import 'services/product_facets.dart';

void main() => runApp(const ComparadorApp());

class ComparadorApp extends StatelessWidget {
  const ComparadorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Comparador inteligente',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF176B52)),
        scaffoldBackgroundColor: const Color(0xFFF6F8F7),
      ),
      home: const HomePage(),
    );
  }
}

class Store {
  const Store(this.name, this.url);
  final String name;
  final String url;
}

const stores = <Store>[
  Store('Carrefour', 'https://www.carrefour.com.ar/'),
  Store('Jumbo', 'https://www.jumbo.com.ar/'),
  Store('Coto', 'https://www.cotodigital.com.ar/'),
  Store('Disco', 'https://www.disco.com.ar/'),
  Store('Vea', 'https://www.vea.com.ar/'),
  Store('ChangoMás', 'https://www.masonline.com.ar/'),
  Store('DIA', 'https://diaonline.supermercadosdia.com.ar/'),
];

class ShoppingItem {
  ShoppingItem(
    this.name, {
    this.quantity = 1,
    this.ean,
    this.offers = const [],
    this.observedAt,
  });

  final String name;
  int quantity;
  final String? ean;
  List<StoreOffer> offers;
  DateTime? observedAt;

  Map<String, dynamic> toJson() => {
        'name': name,
        'quantity': quantity,
        'ean': ean,
        'offers': offers.map((offer) => offer.toJson()).toList(),
        'observedAt': observedAt?.toIso8601String(),
      };

  factory ShoppingItem.fromJson(Map<String, dynamic> json) => ShoppingItem(
        json['name'] as String,
        quantity: (json['quantity'] as num?)?.toInt() ?? 1,
        ean: json['ean']?.toString(),
        offers: (json['offers'] as List<dynamic>? ?? [])
            .whereType<Map<String, dynamic>>()
            .map(StoreOffer.fromJson)
            .toList(),
        observedAt: DateTime.tryParse(json['observedAt']?.toString() ?? ''),
      );
}

class _BasketTotal {
  const _BasketTotal(this.store, this.total, this.missing);
  final String store;
  final double total;
  final int missing;
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final searchController = TextEditingController();
  final brandFilterController = TextEditingController();
  final variantFilterController = TextEditingController();
  final packageFilterController = TextEditingController();
  final sizeFilterController = TextEditingController();
  final basket = <ShoppingItem>[];
  final catalogService = CatalogService();
  int page = 0;
  bool loading = true;
  bool searching = false;
  bool loadingDiscovery = false;
  int discoveryRequest = 0;
  String? discoveryError;
  String? message;
  String? searchError;
  String? selectedBrand;
  String? selectedCategory;
  final Map<String, String> selectedFacets = {};
  String sortMode = 'price';
  CatalogSearchResult? searchResult;
  CatalogSearchResult? discoveryResult;

  @override
  void initState() {
    super.initState();
    _loadBasket();
  }

  @override
  void dispose() {
    searchController.dispose();
    brandFilterController.dispose();
    variantFilterController.dispose();
    packageFilterController.dispose();
    sizeFilterController.dispose();
    catalogService.close();
    super.dispose();
  }

  Future<void> _loadBasket() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('shopping_list_v1');
      if (raw != null) {
        final decoded = jsonDecode(raw) as List<dynamic>;
        basket
          ..clear()
          ..addAll(decoded.map((item) =>
              ShoppingItem.fromJson(item as Map<String, dynamic>)));
      }
    } catch (_) {
      message = 'No se pudo recuperar la lista guardada.';
    }
    if (mounted) setState(() => loading = false);
  }

  Future<void> _saveBasket() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'shopping_list_v1',
      jsonEncode(basket.map((item) => item.toJson()).toList()),
    );
  }

  String get query => searchController.text.trim();

  List<CatalogProduct> get _visibleProducts {
    final category = selectedCategory;
    final products = <CatalogProduct>[];
    for (final product in searchResult?.products ?? const <CatalogProduct>[]) {
      final matchingOffers = product.offers.where((offer) {
        final offerText = [offer.name, offer.variant ?? ''].join(' ');
        final categoryMatch = category == null ||
            ProductFacets.isCategoryProduct(category, offerText) ||
            ProductFacets.isCategoryProduct(category, product.name);
        final offerBrand = ProductFacets.normalize(
          offer.brand ?? product.brand ?? '',
        );
        final brandMatch = selectedBrand == null ||
            offerBrand == ProductFacets.normalize(selectedBrand!);
        final facetMatch = category == null ||
            ProductFacets.matches(
              category,
              offerText.isEmpty ? product.name : offerText,
              selectedFacets,
            );
        return categoryMatch && brandMatch && facetMatch;
      }).toList();
      if (matchingOffers.isEmpty) continue;
      // If one store confirms an exact EAN match, keep every store offer for
      // that same barcode even when another retailer formats its title
      // differently (for example, omitting "botella" or "1 L").
      final visibleOffers = product.comparableByEan
          ? product.offers
          : matchingOffers;
      products.add(CatalogProduct(
        name: product.name,
        ean: product.ean,
        brand: product.brand,
        comparableByEan: product.comparableByEan,
        offers: visibleOffers,
      ));
    }
    if (sortMode == 'brand') {
      products.sort((a, b) => (a.brand ?? a.name)
          .toLowerCase()
          .compareTo((b.brand ?? b.name).toLowerCase()));
    } else {
      products.sort((a, b) =>
          a.offers.first.price.compareTo(b.offers.first.price));
    }
    return products;
  }

  void _updateCategoryFromQuery(String value) {
    final category = ProductFacets.categoryForQuery(value);
    if (category == selectedCategory) return;
    setState(() {
      selectedCategory = category;
      selectedFacets.clear();
      selectedBrand = null;
      searchResult = null;
      discoveryResult = null;
      searchError = null;
      brandFilterController.clear();
      variantFilterController.clear();
      packageFilterController.clear();
      sizeFilterController.clear();
    });
    if (category != null) _loadCategoryDiscovery(category);
  }

  Future<void> _loadCategoryDiscovery(String category) async {
    final request = ++discoveryRequest;
    setState(() {
      loadingDiscovery = true;
      discoveryError = null;
      discoveryResult = null;
      selectedBrand = null;
      selectedFacets.clear();
    });
    try {
      // One category discovery per selection; the returned catalog records
      // are reused to populate all dependent dropdowns.
      final result = await catalogService.search(
        ProductFacets.categories[category]!,
        limit: 50,
      );
      if (!mounted || selectedCategory != category || request != discoveryRequest) return;
      setState(() => discoveryResult = result);
    } catch (error) {
      if (!mounted || selectedCategory != category || request != discoveryRequest) return;
      setState(() => discoveryError =
          error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted && request == discoveryRequest) setState(() => loadingDiscovery = false);
    }
  }

  bool _isCategoryCatalogProduct(CatalogProduct product) {
    final category = selectedCategory;
    if (category == null) return false;
    return product.offers.any((offer) =>
        ProductFacets.isCategoryProduct(category, offer.name) ||
        ProductFacets.isCategoryProduct(category, product.name));
  }

  List<String> get _availableBrandOptions {
    final values = <String, String>{};
    for (final product in discoveryResult?.products ?? const <CatalogProduct>[]) {
      if (!_isCategoryCatalogProduct(product)) continue;
      for (final offer in product.offers) {
        if (!ProductFacets.isCategoryProduct(
          selectedCategory!,
          offer.name,
        ) && !ProductFacets.isCategoryProduct(
          selectedCategory!,
          product.name,
        )) continue;
        final brand = (offer.brand ?? product.brand ?? '').trim();
        if (brand.isEmpty) continue;
        values.putIfAbsent(ProductFacets.normalize(brand), () => brand);
      }
    }
    final result = values.values.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return result;
  }

  List<CatalogProduct> get _productsForSelectedBrand {
    if (selectedBrand == null) return const [];
    final target = ProductFacets.normalize(selectedBrand!);
    return (discoveryResult?.products ?? const <CatalogProduct>[]).where((product) {
      if (!_isCategoryCatalogProduct(product)) return false;
      return product.offers.any((offer) {
        final offerCategoryMatch =
            ProductFacets.isCategoryProduct(selectedCategory!, offer.name) ||
            ProductFacets.isCategoryProduct(selectedCategory!, product.name);
        final brand = ProductFacets.normalize(offer.brand ?? product.brand ?? '');
        return offerCategoryMatch && brand == target;
      });
    }).toList();
  }

  Map<String, List<String>> get _brandFacetOptions {
    if (selectedCategory == null || selectedBrand == null) return const {};
    final target = ProductFacets.normalize(selectedBrand!);
    final names = _productsForSelectedBrand.expand((product) =>
        product.offers.where((offer) =>
          ProductFacets.normalize(offer.brand ?? product.brand ?? '') == target &&
          (ProductFacets.isCategoryProduct(selectedCategory!, offer.name) ||
           ProductFacets.isCategoryProduct(selectedCategory!, product.name))
        ).expand((offer) => [offer.name, offer.variant ?? '']));
    return ProductFacets.available(selectedCategory!, names);
  }

  String? _selectedFacetValue(Set<String> keys) {
    for (final key in keys) {
      if (selectedFacets.containsKey(key)) return selectedFacets[key];
    }
    return null;
  }

  Widget _catalogDropdown({
    required String label,
    required List<String> options,
    required String? value,
    required ValueChanged<String?>? onChanged,
    String? hint,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      ),
      hint: Text(hint ?? 'Seleccioná una opción'),
      key: ValueKey('$label|$value|${options.join('|')}'),
      items: options
          .map((option) => DropdownMenuItem<String>(
                value: option,
                child: Text(option, overflow: TextOverflow.ellipsis),
              ))
          .toList(),
      onChanged: options.isEmpty ? null : onChanged,
    );
  }

  void _selectFacetGroup(Set<String> keys, String? value) {
    setState(() {
      for (final key in keys) {
        selectedFacets.remove(key);
      }
      if (value != null) {
        for (final entry in _brandFacetOptions.entries) {
          if (keys.contains(entry.key) && entry.value.contains(value)) {
            selectedFacets[entry.key] = value;
            break;
          }
        }
      }
      variantFilterController.text = [
        _selectedFacetValue({'Tipo', 'Variedad', 'Preparación', 'Proceso', 'Sabor', 'Variante'}),
      ].whereType<String>().join(' ');
      packageFilterController.text = [
        _selectedFacetValue({'Envase', 'Presentación'}),
      ].whereType<String>().join(' ');
      sizeFilterController.text = _selectedFacetValue({'Contenido'}) ?? '';
    });
  }

  String get _specificSearchQuery => [
        query,
        brandFilterController.text.trim(),
      ].where((part) => part.isNotEmpty).join(' ');

  Future<void> _performSearch({
    bool keepDiscovery = false,
  }) async {
    if (query.length < 2 || searching) return;
    FocusScope.of(context).unfocus();
    setState(() {
      page = 1;
      searching = true;
      searchError = null;
      searchResult = null;
      if (!keepDiscovery) {
        searchResult = null;
        discoveryResult = null;
        selectedBrand = null;
        selectedFacets.clear();
        sortMode = 'price';
      }
    });
    try {
      final result = await catalogService.search(
        query,
        catalogQuery: _specificSearchQuery,
        limit: 50,
      );
      if (!mounted) return;
      setState(() {
        searchResult = result;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() =>
          searchError = error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => searching = false);
    }
  }

  Future<void> _copySearch() async {
    if (query.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: query));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Búsqueda copiada.')),
    );
  }

  Future<void> _openStore(Store store) async => _openUrl(store.url);

  Future<void> _openUrl(String? value) async {
    if (value == null || value.isEmpty) return;
    try {
      final opened = await launchUrl(
        Uri.parse(value),
        mode: LaunchMode.externalApplication,
      );
      if (!opened && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo abrir el enlace.')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo abrir el enlace.')),
        );
      }
    }
  }

  Future<void> _addQuickItem() async {
    final name = query;
    if (name.length < 2) return;
    final normalized = name.toLowerCase().trim();
    final index = basket.indexWhere(
      (item) => item.name.toLowerCase().trim() == normalized,
    );
    setState(() {
      if (index >= 0) {
        basket[index].quantity++;
      } else {
        basket.add(ShoppingItem(name));
      }
    });
    await _saveBasket();
    if (!mounted) return;
    searchController.clear();
    brandFilterController.clear();
    variantFilterController.clear();
    packageFilterController.clear();
    sizeFilterController.clear();
    setState(() {
      selectedCategory = null;
      selectedBrand = null;
      selectedFacets.clear();
      searchResult = null;
      discoveryResult = null;
      searchError = null;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Producto agregado a tu lista. Podés seguir cargando sin esperar los precios.')),
    );
  }

  Future<void> _addProduct(CatalogProduct product) async {
    final index = basket.indexWhere((item) {
      if (product.ean != null && product.ean!.isNotEmpty) {
        return item.ean == product.ean;
      }
      return item.ean == null &&
          item.name.toLowerCase() == product.name.toLowerCase();
    });
    setState(() {
      if (index >= 0) {
        basket[index].quantity++;
        basket[index].offers = product.offers;
        basket[index].observedAt = searchResult?.generatedAt ?? DateTime.now();
      } else {
        basket.add(ShoppingItem(
          product.name,
          ean: product.ean,
          offers: product.offers,
          observedAt: searchResult?.generatedAt ?? DateTime.now(),
        ));
      }
    });
    await _saveBasket();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Producto agregado a tu lista.')),
    );
  }

  Future<void> _changeQuantity(ShoppingItem item, int delta) async {
    setState(() {
      item.quantity += delta;
      if (item.quantity <= 0) basket.remove(item);
    });
    await _saveBasket();
  }

  Future<void> _removeItem(ShoppingItem item) async {
    setState(() => basket.remove(item));
    await _saveBasket();
  }

  List<_BasketTotal> _basketTotals() {
    return stores.map((store) {
      var total = 0.0;
      var missing = 0;
      for (final item in basket) {
        final matching =
            item.offers.where((offer) => offer.store == store.name).toList();
        if (matching.isEmpty) {
          missing++;
        } else {
          matching.sort((a, b) => a.price.compareTo(b.price));
          total += matching.first.price * item.quantity;
        }
      }
      return _BasketTotal(store.name, total, missing);
    }).toList();
  }

  String money(double amount) {
    final digits = amount.round().toString();
    final result = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      result.write(digits[i]);
      final remaining = digits.length - i - 1;
      if (remaining > 0 && remaining % 3 == 0) result.write('.');
    }
    return r'$' + result.toString();
  }

  String _dateLabel(DateTime? value) {
    if (value == null) return 'Sin fecha de consulta';
    final local = value.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$day/$month/${local.year} $hour:$minute';
  }

  String _promotionLabel(Map<String, dynamic> promotion) {
    final parts = <String>[];
    final description = promotion['text']?.toString();
    if (description != null && description.trim().isNotEmpty) {
      parts.add(description.trim());
    }
    final promotionalPrice = promotion['price'];
    if (promotionalPrice is num && promotionalPrice > 0) {
      parts.add('Precio promocional: ${money(promotionalPrice.toDouble())}');
    }
    final restriction = promotion['restriction']?.toString();
    if (restriction != null && restriction.trim().isNotEmpty) {
      parts.add(restriction.trim());
    }
    return parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFFF6F8F7),
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('comparador inteligente',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 19)),
            Text('precios publicados en supermercados',
                style: TextStyle(fontSize: 11, color: Colors.black54)),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Mi lista',
            onPressed: () => setState(() => page = 2),
            icon: Badge(
              label: Text('${basket.length}'),
              child: const Icon(Icons.shopping_basket_outlined),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: loading
            ? const Center(child: CircularProgressIndicator())
            : IndexedStack(
                index: page,
                children: [
                  _searchPage(),
                  _storesPage(),
                  _basketPage(),
                ],
              ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: page,
        onDestinationSelected: (value) => setState(() => page = value),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.search), label: 'Buscar'),
          NavigationDestination(
              icon: Icon(Icons.storefront), label: 'Resultados'),
          NavigationDestination(icon: Icon(Icons.list_alt), label: 'Mi lista'),
        ],
      ),
    );
  }

  Widget _searchPage() {
    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF176B52), Color(0xFF2B8A69)],
            ),
            borderRadius: BorderRadius.circular(22),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Una búsqueda, siete supermercados',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 21,
                      fontWeight: FontWeight.bold)),
              SizedBox(height: 7),
              Text(
                'Buscá por nombre o código de barras. Elegí la presentación exacta y compará los precios publicados.',
                style: TextStyle(color: Colors.white, height: 1.35),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        const Text('Elegí una categoría para empezar',
            style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 7),
        Wrap(
          spacing: 7,
          runSpacing: 6,
          children: ProductFacets.categories.keys.map((category) =>
              ChoiceChip(
                label: Text(category),
                selected: selectedCategory == category,
                onSelected: searching ? null : (selected) {
                  setState(() {
                    selectedCategory = selected ? category : null;
                    selectedFacets.clear();
                    selectedBrand = null;
                    brandFilterController.clear();
                    variantFilterController.clear();
                    packageFilterController.clear();
                    sizeFilterController.clear();
                    searchResult = null;
                    discoveryResult = null;
                    searchController.text = selected
                        ? ProductFacets.categories[category]!
                        : '';
                    loadingDiscovery = false;
                    discoveryError = null;
                  });
                  if (selected) _loadCategoryDiscovery(category);
                },
              )).toList(),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: searchController,
          textInputAction: TextInputAction.search,
          onSubmitted: (_) => _updateCategoryFromQuery(query),
          decoration: InputDecoration(
            hintText: '¿Qué buscás? Ej. leche, aceite, crema, yogur…',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: IconButton(
              onPressed: () {
                searchController.clear();
                brandFilterController.clear();
                variantFilterController.clear();
                packageFilterController.clear();
                sizeFilterController.clear();
                setState(() {
                  selectedCategory = null;
                  selectedBrand = null;
                  selectedFacets.clear();
                  searchResult = null;
                  discoveryResult = null;
                  searchError = null;
                });
              },
              icon: const Icon(Icons.close),
            ),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
          ),
          onChanged: _updateCategoryFromQuery,
        ),
        if (query.length >= 2) ...[
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: searching ? null : _addQuickItem,
              icon: const Icon(Icons.playlist_add),
              label: const Text('Agregar a mi lista sin buscar precios'),
            ),
          ),
        ],
        if (selectedCategory != null) ...[
          const SizedBox(height: 16),
          Text('Precisá $selectedCategory',
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
          const SizedBox(height: 6),
          const Text(
            'Elegí entre las opciones que aparecen en los catálogos. Cada lista depende de la marca y de las presentaciones publicadas para ese producto.',
            style: TextStyle(color: Colors.black54, fontSize: 12),
          ),
          const SizedBox(height: 10),
          if (loadingDiscovery)
            const Text('Consultando las opciones disponibles en los catálogos...',
                style: TextStyle(color: Colors.black54, fontSize: 12)),
          if (discoveryError != null)
            Text(
              'No pudimos cargar las opciones del catálogo: $discoveryError',
              style: const TextStyle(color: Colors.red, fontSize: 12),
            ),
          _catalogDropdown(
            label: 'Marca',
            options: _availableBrandOptions,
            value: selectedBrand,
            hint: loadingDiscovery ? 'Cargando marcas...' : 'Elegí una marca',
            onChanged: (value) {
              setState(() {
                selectedBrand = value;
                selectedFacets.clear();
                brandFilterController.text = value ?? '';
                variantFilterController.clear();
                packageFilterController.clear();
                sizeFilterController.clear();
              });
            },
          ),
          const SizedBox(height: 8),
          _catalogDropdown(
            label: 'Tipo o variedad',
            options: _brandFacetOptions.entries
                .where((entry) => {'Tipo', 'Variedad', 'Preparación', 'Proceso', 'Sabor', 'Variante'}.contains(entry.key))
                .expand((entry) => entry.value)
                .toSet().toList()..sort(),
            value: _selectedFacetValue({'Tipo', 'Variedad', 'Preparación', 'Proceso', 'Sabor', 'Variante'}),
            hint: selectedBrand == null ? 'Primero elegí una marca' : 'Elegí el tipo o variedad',
            onChanged: selectedBrand == null ? null : (value) => _selectFacetGroup(
              {'Tipo', 'Variedad', 'Preparación', 'Proceso', 'Sabor', 'Variante'}, value),
          ),
          const SizedBox(height: 8),
          _catalogDropdown(
            label: 'Envase o presentación',
            options: _brandFacetOptions.entries
                .where((entry) => {'Envase', 'Presentación'}.contains(entry.key))
                .expand((entry) => entry.value)
                .toSet().toList()..sort(),
            value: _selectedFacetValue({'Envase', 'Presentación'}),
            hint: selectedBrand == null ? 'Primero elegí una marca' : 'Elegí la presentación',
            onChanged: selectedBrand == null ? null : (value) => _selectFacetGroup({'Envase', 'Presentación'}, value),
          ),
          const SizedBox(height: 8),
          _catalogDropdown(
            label: 'Contenido',
            options: _brandFacetOptions['Contenido'] ?? const [],
            value: _selectedFacetValue({'Contenido'}),
            hint: selectedBrand == null ? 'Primero elegí una marca' : 'Elegí el contenido',
            onChanged: selectedBrand == null ? null : (value) => _selectFacetGroup({'Contenido'}, value),
          ),
        ],
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: query.length < 2 || searching ? null : () => _performSearch(keepDiscovery: true),
          icon: searching
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.travel_explore),
          label: Text(searching ? 'Buscando...' : 'Buscar en los supermercados'),
        ),
        const SizedBox(height: 18),
        const _Notice(
          title: 'Cómo se comparan los productos',
          body: 'Cuando hay código EAN, la app compara únicamente el mismo código de barras. Si una tienda no devuelve ese producto, no inventamos un precio ni lo reemplazamos por otra presentación.',
          icon: Icons.verified_outlined,
        ),
        if (message != null) ...[
          const SizedBox(height: 10),
          Text(message!, style: const TextStyle(color: Colors.red)),
        ],
      ],
    );
  }

  Widget _storesPage() {
    final result = searchResult;
    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        Text(
          query.isEmpty ? 'Resultados' : 'Resultados para $query',
          style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        if (query.isNotEmpty && !searching)
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: _copySearch,
              icon: const Icon(Icons.copy),
              label: const Text('Copiar búsqueda'),
            ),
          ),
        if (searching) ...[
          const LinearProgressIndicator(),
          const SizedBox(height: 12),
          const Text('Consultando los catálogos online...'),
        ] else if (searchError != null) ...[
          _Notice(
            title: 'No pudimos completar la búsqueda',
            body: searchError!,
            icon: Icons.error_outline,
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () => _performSearch(keepDiscovery: true),
            icon: const Icon(Icons.refresh),
            label: const Text('Reintentar'),
          ),
        ] else if (result == null) ...[
          const _Notice(
            title: 'Buscá un producto para empezar',
            body: 'La app consulta los catálogos de las siete cadenas y muestra los precios que cada una publica.',
            icon: Icons.search,
          ),
        ] else ...[
          Text(
            'Consulta: ${_dateLabel(result.generatedAt)}',
            style: const TextStyle(color: Colors.black54, fontSize: 12),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: result.stores
                .map((status) {
                  final count = result.products
                      .expand((product) => product.offers)
                      .where((offer) => offer.store == status.store)
                      .length;
                  return Chip(
                    avatar: Icon(
                      status.ok ? Icons.check_circle : Icons.error_outline,
                      size: 16,
                      color: status.ok
                          ? Colors.green.shade700
                          : Colors.red.shade700,
                    ),
                    label: Text('${status.store}: $count'),
                    visualDensity: VisualDensity.compact,
                  );
                })
                .toList(),
          ),
          if (result.stores.any((status) => !status.ok)) ...[
            const SizedBox(height: 8),
            const Text(
              'Algunos supermercados no pudieron consultarse:',
              style: TextStyle(fontWeight: FontWeight.w600, color: Colors.red),
            ),
            ...result.stores.where((status) => !status.ok).map((status) =>
                Text(
                  '${status.store}: ${status.error ?? 'sin respuesta'}'
                  '\${status.status == null ? '' : ' (HTTP ${status.status})'}',
                  style: const TextStyle(fontSize: 12, color: Colors.red),
                )),
          ],
          if (result.products.isEmpty) ...[
            const SizedBox(height: 16),
            const _Notice(
              title: 'No encontramos productos',
              body: 'Probá con otro nombre o con el código de barras EAN.',
              icon: Icons.search_off,
            ),
          ] else ...[
            const SizedBox(height: 8),
            Text(
              '${_visibleProducts.length} opciones encontradas',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            const Text(
              'Estos son los productos que coinciden con los filtros elegidos. Por defecto, están ordenados desde el menor precio.',
              style: TextStyle(color: Colors.black54, fontSize: 12),
            ),
            const SizedBox(height: 10),
            DropdownButton<String>(
              value: sortMode,
              underline: const SizedBox.shrink(),
              items: const [
                DropdownMenuItem(value: 'price', child: Text('Menor precio primero')),
                DropdownMenuItem(value: 'brand', child: Text('Ordenar por marca')),
              ],
              onChanged: (value) => setState(() => sortMode = value ?? 'price'),
            ),
            const SizedBox(height: 8),
            if (_visibleProducts.isEmpty)
              const Text('No hay productos con esos filtros.')
            else
              ..._visibleProducts.map(_productCard),
          ],
          const SizedBox(height: 12),
          const _Notice(
            title: 'Importante sobre los precios',
            body: 'Son precios publicados en catálogos online al momento de la consulta. Pueden variar por sucursal, código postal, stock y medio de pago. Coto usa una sucursal de referencia hasta que se configure la ubicación.',
            icon: Icons.info_outline,
          ),
        ],
        const SizedBox(height: 14),
        const Divider(),
        const Text('Abrir un supermercado',
            style: TextStyle(fontWeight: FontWeight.bold)),
        ...stores.map((store) => ListTile(
              dense: true,
              leading: const Icon(Icons.storefront_outlined),
              title: Text(store.name),
              trailing: const Icon(Icons.open_in_new, size: 18),
              onTap: () => _openStore(store),
            )),
      ],
    );
  }

  Widget _productCard(CatalogProduct product) {
    if (product.offers.isEmpty) return const SizedBox.shrink();
    final cheapestOffer = product.offers.reduce(
      (a, b) => a.price <= b.price ? a : b,
    );
    final imageOffer = product.offers.firstWhere(
      (offer) => offer.image != null && offer.image!.isNotEmpty,
      orElse: () => product.offers.first,
    );
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(13),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (imageOffer.image != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.network(
                      imageOffer.image!,
                      headers: const {
                        'User-Agent':
                            'Mozilla/5.0 (Linux; Android 10) AppleWebKit/537.36 Chrome/120.0.0.0 Mobile Safari/537.36',
                      },
                      width: 68,
                      height: 68,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const SizedBox(
                        width: 68,
                        height: 68,
                        child: Icon(Icons.shopping_bag_outlined, size: 32),
                      ),
                    ),
                  )
                else
                  const SizedBox(
                    width: 68,
                    height: 68,
                    child: Icon(Icons.shopping_bag_outlined, size: 32),
                  ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(product.name,
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      if (product.brand != null)
                        Text(product.brand!,
                            style: const TextStyle(
                                color: Colors.black54, fontSize: 12)),
                      if (imageOffer.variant != null &&
                          imageOffer.variant!.trim().isNotEmpty)
                        Text(
                          imageOffer.variant!,
                          style: const TextStyle(
                              color: Colors.black54, fontSize: 11),
                        ),
                      Text(
                        product.comparableByEan
                            ? 'EAN: ${product.ean}'
                            : 'Sin EAN · no comparable por código',
                        style: const TextStyle(
                            color: Colors.black54, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
              decoration: BoxDecoration(
                color: const Color(0xFFEAF4EF),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'Menor precio: ${money(cheapestOffer.price)} en ${cheapestOffer.store} · ${product.offers.length} supermercado(s) comparado(s)',
                style: const TextStyle(
                  color: Color(0xFF176B52),
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(height: 6),
            ...product.offers.map((offer) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(offer.store,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600)),
                            if (offer.price == cheapestOffer.price)
                              const Text(
                                'MENOR PRECIO',
                                style: TextStyle(
                                  color: Color(0xFF176B52),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            Text(
                              offer.branchLabel ??
                                  (offer.priceType == 'online_default_channel'
                                      ? 'Precio online'
                                      : 'Precio publicado'),
                              style: const TextStyle(
                                  color: Colors.black54, fontSize: 10),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(money(offer.price),
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold)),
                          if (offer.listPrice != null &&
                              offer.listPrice! > offer.price)
                            Text(
                              'Lista: ${money(offer.listPrice!)}',
                              style: const TextStyle(
                                  color: Colors.black54,
                                  fontSize: 10,
                                  decoration: TextDecoration.lineThrough),
                            ),
                          if (offer.promotions.isNotEmpty)
                            SizedBox(
                              width: 190,
                              child: Text(
                                offer.promotions
                                    .map(_promotionLabel)
                                    .where((label) => label.isNotEmpty)
                                    .join('\n'),
                                textAlign: TextAlign.end,
                                style: const TextStyle(
                                  color: Color(0xFF176B52),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                        ],
                      ),
                      IconButton(
                        tooltip: 'Ver producto en la tienda',
                        visualDensity: VisualDensity.compact,
                        onPressed: () => _openUrl(offer.url),
                        icon: const Icon(Icons.open_in_new, size: 18),
                      ),
                    ],
                  ),
                )),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton.tonalIcon(
                onPressed: () => _addProduct(product),
                icon: const Icon(Icons.add_shopping_cart),
                label: const Text('Agregar a mi lista'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _basketPage() {
    final totals = _basketTotals();
    final complete = totals.where((item) => item.missing == 0).toList()
      ..sort((a, b) => a.total.compareTo(b.total));
    final bestStore = complete.isEmpty ? null : complete.first.store;
    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        const Text('Mi lista de compras',
            style: TextStyle(fontSize: 23, fontWeight: FontWeight.w800)),
        const SizedBox(height: 5),
        const Text('La lista queda guardada en este teléfono.',
            style: TextStyle(color: Colors.black54)),
        const SizedBox(height: 14),
        if (basket.isEmpty)
          const _Notice(
            title: 'Tu lista está vacía',
            body: 'Escribí el producto con la marca y presentación que querés, y agregalo sin esperar la búsqueda de precios.',
            icon: Icons.add_shopping_cart,
          )
        else ...[
          ...basket.map((item) {
            final sortedOffers = item.offers.toList()
              ..sort((a, b) => a.price.compareTo(b.price));
            final bestOffer =
                sortedOffers.isEmpty ? null : sortedOffers.first;
            return Card(
              elevation: 0,
              margin: const EdgeInsets.only(bottom: 8),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(item.name,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600)),
                        ),
                        IconButton(
                          tooltip: 'Eliminar',
                          onPressed: () => _removeItem(item),
                          icon: const Icon(Icons.delete_outline),
                        ),
                      ],
                    ),
                    if (item.ean != null)
                      Text('EAN: ${item.ean}',
                          style: const TextStyle(
                              color: Colors.black54, fontSize: 11)),
                    if (item.offers.isEmpty)
                      const Text(
                        'Pendiente de comparar · todavía no consultamos precios',
                        style: TextStyle(color: Colors.deepOrange, fontSize: 12),
                      ),
                    if (bestOffer != null)
                      Text(
                        'Mejor precio consultado: ${money(bestOffer.price)} en ${bestOffer.store}',
                        style: const TextStyle(
                            color: Color(0xFF176B52),
                            fontWeight: FontWeight.w600,
                            fontSize: 12),
                      ),
                    Text(
                      'Precios consultados: ${_dateLabel(item.observedAt)}',
                      style: const TextStyle(
                          color: Colors.black54, fontSize: 10),
                    ),
                    Row(
                      children: [
                        IconButton(
                          onPressed: () => _changeQuantity(item, -1),
                          icon: const Icon(Icons.remove_circle_outline),
                        ),
                        Text('${item.quantity}',
                            style: const TextStyle(fontWeight: FontWeight.bold)),
                        IconButton(
                          onPressed: () => _changeQuantity(item, 1),
                          icon: const Icon(Icons.add_circle_outline),
                        ),
                        const Spacer(),
                        Text(
                          bestOffer == null
                              ? 'Sin precio'
                              : money(bestOffer.price * item.quantity),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 8),
          const Text('Comparación de la lista completa',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
          const SizedBox(height: 8),
          if (bestStore == null)
            const _Notice(
              title: 'Todavía no hay una tienda con todos los productos',
              body: 'Algunas tiendas no publican todos los artículos. La app no considera completo un total si faltan productos.',
              icon: Icons.info_outline,
            ),
          ...totals.map((item) => Card(
                elevation: 0,
                margin: const EdgeInsets.only(bottom: 7),
                child: ListTile(
                  leading: Icon(
                    item.store == bestStore
                        ? Icons.emoji_events_outlined
                        : Icons.storefront_outlined,
                    color: item.store == bestStore
                        ? const Color(0xFF176B52)
                        : null,
                  ),
                  title: Text(item.store,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(item.missing == 0
                      ? 'Todos los productos encontrados'
                      : 'Faltan ${item.missing} de ${basket.length} productos'),
                  trailing: Text(
                    item.missing == 0 ? money(item.total) : 'Incompleto',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              )),
          const SizedBox(height: 8),
          const _Notice(
            title: 'Antes de ir a comprar',
            body: 'La comparación usa los precios guardados al agregar cada producto. Actualizá la búsqueda antes de comprar para confirmar que sigan vigentes.',
            icon: Icons.schedule,
          ),
          OutlinedButton.icon(
            onPressed: () async {
              setState(() => basket.clear());
              await _saveBasket();
            },
            icon: const Icon(Icons.delete_sweep_outlined),
            label: const Text('Vaciar lista'),
          ),
        ],
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: () => setState(() => page = 0),
          icon: const Icon(Icons.search),
          label: const Text('Buscar más productos'),
        ),
      ],
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.title, required this.body, required this.icon});
  final String title;
  final String body;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE1E8E4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: const Color(0xFF176B52)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 5),
                Text(body, style: const TextStyle(
                    color: Colors.black54, height: 1.35, fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
