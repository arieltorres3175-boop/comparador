import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

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
  Store('Coto', 'https://www.coto.com.ar/'),
  Store('Disco', 'https://www.disco.com.ar/'),
  Store('Vea', 'https://www.vea.com.ar/'),
  Store('ChangoMás', 'https://www.masonline.com.ar/'),
  Store('DIA', 'https://diaonline.supermercadosdia.com.ar/'),
];

class ShoppingItem {
  ShoppingItem(this.name, {this.quantity = 1});
  final String name;
  int quantity;

  Map<String, dynamic> toJson() => {'name': name, 'quantity': quantity};

  factory ShoppingItem.fromJson(Map<String, dynamic> json) => ShoppingItem(
        json['name'] as String,
        quantity: (json['quantity'] as num?)?.toInt() ?? 1,
      );
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final searchController = TextEditingController();
  final basket = <ShoppingItem>[];
  int page = 0;
  bool loading = true;
  String? message;

  @override
  void initState() {
    super.initState();
    _loadBasket();
  }

  @override
  void dispose() {
    searchController.dispose();
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

  Future<void> _copySearch() async {
    if (query.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: query));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Búsqueda copiada. Pegala en el supermercado.')),
    );
  }

  Future<void> _openStore(Store store) async {
    final uri = Uri.parse(store.url);
    try {
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!opened && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo abrir ${store.name}.')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo abrir ${store.name}.')),
        );
      }
    }
  }

  Future<void> _addItem() async {
    final name = query;
    if (name.isEmpty) return;
    final index = basket.indexWhere(
      (item) => item.name.toLowerCase() == name.toLowerCase(),
    );
    setState(() {
      if (index >= 0) {
        basket[index].quantity++;
      } else {
        basket.add(ShoppingItem(name));
      }
      message = null;
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
            Text('buscá en supermercados y armá tu lista',
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
          NavigationDestination(icon: Icon(Icons.storefront), label: 'Supermercados'),
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
                  style: TextStyle(color: Colors.white, fontSize: 21,
                      fontWeight: FontWeight.bold)),
              SizedBox(height: 7),
              Text(
                'Escribí el producto que buscás. Desde acá podés copiarlo y abrir cada tienda para consultar su catálogo.',
                style: TextStyle(color: Colors.white, height: 1.35),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        TextField(
          controller: searchController,
          textInputAction: TextInputAction.search,
          onSubmitted: (_) => setState(() => page = 1),
          decoration: InputDecoration(
            hintText: 'Ej. leche La Serenísima entera 1 litro',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: IconButton(
              onPressed: () {
                searchController.clear();
                setState(() {});
              },
              icon: const Icon(Icons.close),
            ),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: query.isEmpty ? null : () => setState(() => page = 1),
          icon: const Icon(Icons.travel_explore),
          label: const Text('Ver supermercados'),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: query.isEmpty ? null : _addItem,
          icon: const Icon(Icons.add_shopping_cart),
          label: const Text('Agregar a mi lista'),
        ),
        const SizedBox(height: 20),
        const _Notice(
          title: 'Importante sobre los precios',
          body: 'Esta versión todavía no consulta ni compara precios automáticamente. No muestra importes inventados: abre los sitios oficiales para que puedas verificar precio, presentación y disponibilidad.',
          icon: Icons.info_outline,
        ),
        if (message != null) ...[
          const SizedBox(height: 10),
          Text(message!, style: const TextStyle(color: Colors.red)),
        ],
      ],
    );
  }

  Widget _storesPage() {
    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        const Text('Consultar supermercados',
            style: TextStyle(fontSize: 23, fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        Text(
          query.isEmpty
              ? 'Volvé a Buscar y escribí un producto para copiarlo.'
              : 'Producto a consultar: $query',
          style: const TextStyle(color: Colors.black54),
        ),
        const SizedBox(height: 12),
        if (query.isNotEmpty)
          FilledButton.tonalIcon(
            onPressed: _copySearch,
            icon: const Icon(Icons.copy),
            label: const Text('Copiar nombre del producto'),
          ),
        const SizedBox(height: 8),
        ...stores.map((store) => Card(
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 9),
          child: ListTile(
            leading: const CircleAvatar(
              backgroundColor: Color(0xFFE7F1EC),
              child: Icon(Icons.storefront, color: Color(0xFF176B52)),
            ),
            title: Text(store.name,
                style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: const Text('Sitio oficial · búsqueda manual'),
            trailing: const Icon(Icons.open_in_new),
            onTap: () => _openStore(store),
          ),
        )),
        const SizedBox(height: 8),
        const _Notice(
          title: 'Cómo usar esta versión',
          body: 'Copiá el producto, abrí una tienda y pegalo en su buscador. La app aún no extrae resultados ni confirma precios por sí sola.',
          icon: Icons.lightbulb_outline,
        ),
      ],
    );
  }

  Widget _basketPage() {
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
            body: 'Buscá un producto y tocá “Agregar a mi lista”.',
            icon: Icons.add_shopping_cart,
          )
        else ...[
          ...basket.map((item) => Card(
            elevation: 0,
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              title: Text(item.name,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text('Cantidad: ${item.quantity}'),
              leading: const Icon(Icons.shopping_bag_outlined),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'Quitar uno',
                    onPressed: () => _changeQuantity(item, -1),
                    icon: const Icon(Icons.remove_circle_outline),
                  ),
                  IconButton(
                    tooltip: 'Agregar uno',
                    onPressed: () => _changeQuantity(item, 1),
                    icon: const Icon(Icons.add_circle_outline),
                  ),
                  IconButton(
                    tooltip: 'Eliminar',
                    onPressed: () => _removeItem(item),
                    icon: const Icon(Icons.delete_outline),
                  ),
                ],
              ),
            ),
          )),
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
          onPressed: () => setState(() => page = 1),
          icon: const Icon(Icons.storefront),
          label: const Text('Consultar supermercados'),
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
