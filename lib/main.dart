import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() => runApp(const ComparadorApp());

class ComparadorApp extends StatelessWidget {
  const ComparadorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Comparador inteligente',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF167D55)),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

class Product {
  const Product(this.name, this.category, this.brand, this.size, this.price);
  final String name, category, brand, size;
  final double price;

  Map<String, dynamic> toJson() => {
    'name': name, 'category': category, 'brand': brand, 'size': size, 'price': price
  };

  factory Product.fromJson(Map<String, dynamic> json) => Product(
    json['name'] as String,
    json['category'] as String,
    json['brand'] as String,
    json['size'] as String,
    (json['price'] as num).toDouble(),
  );
}

const products = <Product>[
  Product('Leche entera', 'Leches', 'Marca de ejemplo', '1 litro', 1450),
  Product('Leche descremada', 'Leches', 'Marca de ejemplo', '1 litro', 1490),
  Product('Yogur firme', 'Yogures', 'Marca de ejemplo', '190 g', 980),
  Product('Yogur bebible', 'Yogures', 'Marca de ejemplo', '1 litro', 2100),
  Product('Manteca', 'Mantecas', 'Marca de ejemplo', '200 g', 2300),
  Product('Queso cremoso', 'Quesos', 'Marca de ejemplo', '1 kg', 8900),
];

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int tab = 0;
  String purchaseType = 'Minorista';
  final List<Product> shoppingList = [];
  bool loaded = false;

  @override
  void initState() {
    super.initState();
    _loadList();
  }

  Future<void> _loadList() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('shopping_list');
    if (raw != null) {
      final decoded = jsonDecode(raw) as List<dynamic>;
      shoppingList.addAll(decoded.map((e) => Product.fromJson(e as Map<String, dynamic>)));
    }
    if (mounted) setState(() => loaded = true);
  }

  Future<void> _saveList() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('shopping_list',
        jsonEncode(shoppingList.map((p) => p.toJson()).toList()));
  }

  void _add(Product product) {
    setState(() => shoppingList.add(product));
    _saveList();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${product.name} agregada a tu lista')),
    );
  }

  void _remove(int index) {
    setState(() => shoppingList.removeAt(index));
    _saveList();
  }

  String money(double value) =>
      '\$${value.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]}.')}';

  @override
  Widget build(BuildContext context) {
    final pages = [
      _catalogPage(),
      _listPage(),
      _bestDayPage(),
      _promotionsPage(),
    ];
    return Scaffold(
      appBar: AppBar(
        title: const Text('Comparador inteligente', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: false,
      ),
      body: loaded ? pages[tab] : const Center(child: CircularProgressIndicator()),
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (value) => setState(() => tab = value),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.storefront_outlined), selectedIcon: Icon(Icons.storefront), label: 'Comprar'),
          NavigationDestination(icon: Icon(Icons.shopping_cart_outlined), selectedIcon: Icon(Icons.shopping_cart), label: 'Mi lista'),
          NavigationDestination(icon: Icon(Icons.calendar_month_outlined), selectedIcon: Icon(Icons.calendar_month), label: 'Mejor día'),
          NavigationDestination(icon: Icon(Icons.local_offer_outlined), selectedIcon: Icon(Icons.local_offer), label: 'Promos'),
        ],
      ),
    );
  }

  Widget _catalogPage() => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      SegmentedButton<String>(
        segments: const [
          ButtonSegment(value: 'Minorista', label: Text('Minorista'), icon: Icon(Icons.shopping_basket)),
          ButtonSegment(value: 'Mayorista', label: Text('Mayorista'), icon: Icon(Icons.warehouse)),
        ],
        selected: {purchaseType},
        onSelectionChanged: (v) => setState(() => purchaseType = v.first),
      ),
      const SizedBox(height: 16),
      Text('Catálogo inicial · $purchaseType', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 6),
      const Text('Productos de muestra para probar la aplicación. Los precios no son reales.'),
      const SizedBox(height: 12),
      ...products.map((p) => Card(
        child: ListTile(
          leading: CircleAvatar(child: Icon(_categoryIcon(p.category))),
          title: Text(p.name),
          subtitle: Text('${p.brand} · ${p.size} · ${p.category}'),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(money(p.price), style: const TextStyle(fontWeight: FontWeight.bold)),
              const Text('de muestra', style: TextStyle(fontSize: 10)),
            ],
          ),
          onTap: () => _add(p),
        ),
      )),
      const SizedBox(height: 8),
      const Text('Tocá un producto para agregarlo a tu lista', textAlign: TextAlign.center),
    ],
  );

  IconData _categoryIcon(String category) {
    switch (category) {
      case 'Leches': return Icons.local_drink_outlined;
      case 'Yogures': return Icons.icecream_outlined;
      case 'Mantecas': return Icons.breakfast_dining_outlined;
      default: return Icons.lunch_dining_outlined;
    }
  }

  Widget _listPage() {
    final total = shoppingList.fold<double>(0, (sum, p) => sum + p.price);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Mi lista de compras', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8),
        if (shoppingList.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 48),
            child: Column(children: [
              Icon(Icons.shopping_cart_outlined, size: 56),
              SizedBox(height: 12),
              Text('Todavía no agregaste productos'),
              Text('Entrá en Comprar y tocá los productos que quieras'),
            ]),
          )
        else ...[
          ...shoppingList.asMap().entries.map((entry) => Card(
            child: ListTile(
              title: Text(entry.value.name),
              subtitle: Text('${entry.value.brand} · ${entry.value.size}'),
              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                Text(money(entry.value.price)),
                IconButton(icon: const Icon(Icons.delete_outline), onPressed: () => _remove(entry.key)),
              ]),
            ),
          )),
          const Divider(),
          ListTile(
            title: const Text('Total ilustrativo', style: TextStyle(fontWeight: FontWeight.bold)),
            trailing: Text(money(total), style: Theme.of(context).textTheme.titleLarge),
          ),
          OutlinedButton.icon(
            onPressed: () { setState(shoppingList.clear); _saveList(); },
            icon: const Icon(Icons.delete_sweep_outlined),
            label: const Text('Vaciar lista'),
          ),
        ],
      ],
    );
  }

  Widget _bestDayPage() {
    final total = shoppingList.fold<double>(0, (sum, p) => sum + p.price);
    final examples = [
      ('lunes', total),
      ('martes', total * .97),
      ('miércoles', total * .90),
      ('jueves', total * .96),
      ('viernes', total * .99),
    ];
    return ListView(padding: const EdgeInsets.all(16), children: [
      Text('¿qué día conviene comprar?', style: Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height: 8),
      const Text('Simulación de ejemplo: todavía no utiliza promociones ni precios reales de comercios'),
      const SizedBox(height: 16),
      if (shoppingList.isEmpty)
        const Text('Agregá productos a tu lista para ver una comparación ilustrativa')
      else ...[
        Text('Lista actual: ${shoppingList.length} productos'),
        const SizedBox(height: 8),
        ...examples.map((e) => Card(
          child: ListTile(
            title: Text(e.$1.toUpperCase()),
            subtitle: Text(e.$1 == 'miércoles' ? 'descuento hipotético de ejemplo' : 'valor hipotético'),
            trailing: Text(money(e.$2), style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        )),
        const SizedBox(height: 8),
        const Text('Los porcentajes son ficticios y sirven únicamente para probar la pantalla'),
      ],
    ]);
  }

  Widget _promotionsPage() => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      Text('Promociones y actualizaciones', style: Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height: 8),
      const Card(child: ListTile(
        leading: Icon(Icons.sync),
        title: Text('Actualización por novedades'),
        subtitle: Text('La estructura está preparada para incorporar promociones nuevas y distribuir cambios cuando se conecten las fuentes de datos'),
      )),
      const Card(child: ListTile(
        leading: Icon(Icons.calendar_today_outlined),
        title: Text('Catálogo y precios generales'),
        subtitle: Text('Se podrán sincronizar periódicamente y descargar solo los cambios'),
      )),
      const Card(child: ListTile(
        leading: Icon(Icons.verified_outlined),
        title: Text('Verificación de promociones'),
        subtitle: Text('Cada promoción deberá mostrar fuente, fecha de detección, vigencia y condiciones'),
      )),
      const SizedBox(height: 8),
      const Text('Esta versión todavía no consulta supermercados ni mayoristas'),
    ],
  );
}
