
import 'package:flutter/material.dart';

void main() => runApp(const ComparadorApp());

class ComparadorApp extends StatelessWidget {
  const ComparadorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'comparador inteligente',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF176B52),
        ),
        scaffoldBackgroundColor: const Color(0xFFF6F8F7),
      ),
      home: const HomePage(),
    );
  }
}

class Product {
  const Product(this.id, this.name, this.detail, this.brand, this.price);

  final String id, name, detail, brand;
  final double price;
}

const products = <Product>[
  Product('l1', 'leche entera la serenísima', 'sachet · 1 litro', 'la serenísima', 1650),
  Product('l2', 'leche parcialmente descremada la serenísima', 'larga vida · caja · 1 litro', 'la serenísima', 1890),
  Product('l3', 'leche descremada la serenísima', 'sachet · 1 litro', 'la serenísima', 1720),
  Product('l4', 'leche deslactosada la serenísima', 'larga vida · caja · 1 litro', 'la serenísima', 2150),
  Product('y1', 'yogur bebible la serenísima', 'frutilla · 900 g', 'la serenísima', 2350),
  Product('y2', 'yogur firme la serenísima', 'vainilla · 190 g', 'la serenísima', 890),
  Product('m1', 'manteca sancor', '200 g', 'sancor', 2450),
  Product('q1', 'queso cremoso', 'por kilogramo', 'varias marcas', 9800),
  Product('a1', 'aceite girasol cocinero', '900 ml', 'cocinero', 3100),
  Product('f1', 'fideos matarazzo', '500 g', 'matarazzo', 1450),
  Product('s1', 'azúcar ledesma', '1 kg', 'ledesma', 1600),
];

class Line {
  Line(this.product);

  final Product product;
  int quantity = 1;
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final search = TextEditingController();
  final basket = <Line>[];
  int page = 0;
  String kind = 'minorista';

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  List<Product> get matches {
    final q = search.text.trim().toLowerCase();

    if (q.isEmpty) return [];

    return products.where((p) =>
      p.name.contains(q) || p.brand.contains(q)
    ).toList();
  }

  int count(String id) {
    final i = basket.indexWhere((x) => x.product.id == id);
    return i < 0 ? 0 : basket[i].quantity;
  }

  void add(Product p) {
    setState(() {
      final i = basket.indexWhere((x) => x.product.id == p.id);

      if (i < 0) {
        basket.add(Line(p));
      } else {
        basket[i].quantity++;
      }
    });
  }

  void quantity(Line line, int delta) {
    setState(() {
      line.quantity += delta;

      if (line.quantity <= 0) {
        basket.remove(line);
      }
    });
  }

  double get total => basket.fold(
    0,
    (s, x) => s + x.product.price * x.quantity,
  );

  String money(double n) {
    final s = n.round().toString();
    final b = StringBuffer();

    for (var i = 0; i < s.length; i++) {
      b.write(s[i]);

      if ((s.length - i - 1) > 0 &&
          (s.length - i - 1) % 3 == 0) {
        b.write('.');
      }
    }

    return '\$$b';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFFF6F8F7),
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'comparador inteligente',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 19,
              ),
            ),
            Text(
              'armá tu lista y encontrá dónde ahorrar',
              style: TextStyle(fontSize: 11, color: Colors.black54),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () => setState(() => page = 1),
            icon: Badge(
              label: Text('${basket.length}'),
              child: const Icon(Icons.shopping_basket_outlined),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: page == 0
            ? searchPage()
            : page == 1
                ? listPage()
                : comparePage(),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: page,
        onDestinationSelected: (v) => setState(() => page = v),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.search),
            label: 'buscar',
          ),
          NavigationDestination(
            icon: Icon(Icons.list_alt),
            label: 'mi lista',
          ),
          NavigationDestination(
            icon: Icon(Icons.compare_arrows),
            label: 'comparar',
          ),
        ],
      ),
    );
  }

  Widget searchPage() {
    final found = matches;

    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [
                Color(0xFF176B52),
                Color(0xFF2B8A69),
              ],
            ),
            borderRadius: BorderRadius.circular(22),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'tu compra, más inteligente',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 21,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 6),
              Text(
                'buscá productos, agregalos a tu lista y compará precios y promociones',
                style: TextStyle(color: Colors.white, height: 1.35),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        TextField(
          controller: search,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: 'ej. leche la serenísima',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: search.text.isEmpty
                ? null
                : IconButton(
                    onPressed: () {
                      search.clear();
                      setState(() {});
                    },
                    icon: const Icon(Icons.close),
                  ),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            const Text(
              'tipo de compra',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const Spacer(),
            ChoiceChip(
              label: const Text('minorista'),
              selected: kind == 'minorista',
              onSelected: (_) => setState(() => kind = 'minorista'),
            ),
            const SizedBox(width: 6),
            ChoiceChip(
              label: const Text('mayorista'),
              selected: kind == 'mayorista',
              onSelected: (_) => setState(() => kind = 'mayorista'),
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (search.text.trim().isEmpty) ...[
          const Text(
            'probá buscar',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              'leche la serenísima',
              'yogur',
              'manteca',
              'queso',
              'aceite',
              'fideos',
            ].map((x) => ActionChip(
              label: Text(x),
              onPressed: () {
                search.text = x;
                setState(() {});
              },
            )).toList(),
          ),
          const SizedBox(height: 20),
          const InfoBox(
            icon: Icons.lightbulb_outline,
            title: 'cómo funciona',
            body: 'escribí un producto, elegí la presentación correcta y agregalo a tu lista. después compararemos el costo total en distintos comercios',
          ),
        ] else if (found.isEmpty) ...[
          const SizedBox(height: 30),
          const Icon(Icons.search_off, size: 44, color: Colors.black38),
          const Center(
            child: Text('no encontramos coincidencias en este catálogo de prueba'),
          ),
          const Center(
            child: Text(
              'más adelante se conectará el catálogo nacional',
              style: TextStyle(color: Colors.black54, fontSize: 12),
            ),
          ),
        ] else ...[
          Text(
            '${found.length} opciones encontradas',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          ...found.map((p) => Card(
            elevation: 0,
            margin: const EdgeInsets.only(bottom: 8),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  const CircleAvatar(
                    backgroundColor: Color(0xFFE7F1EC),
                    child: Icon(
                      Icons.shopping_bag_outlined,
                      color: Color(0xFF176B52),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          p.name,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          p.detail,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.black54,
                          ),
                        ),
                        Text(
                          p.brand,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.black45,
                          ),
                        ),
                      ],
                    ),
                  ),
                  FilledButton.tonal(
                    onPressed: () => add(p),
                    child: Text(
                      count(p.id) > 0
                          ? 'agregar (${count(p.id)})'
                          : 'agregar',
                    ),
                  ),
                ],
              ),
            ),
          )),
        ],
        if (basket.isNotEmpty) ...[
          const SizedBox(height: 10),
          FilledButton.icon(
            onPressed: () => setState(() => page = 1),
            icon: const Icon(Icons.shopping_basket_outlined),
            label: Text('ver mi lista · ${basket.length} productos'),
          ),
        ],
      ],
    );
  }

  Widget listPage() {
    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        const Text(
          'mi lista de compras',
          style: TextStyle(fontSize: 23, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 4),
        Text(
          '${basket.length} productos diferentes · compra $kind',
          style: const TextStyle(color: Colors.black54),
        ),
        const SizedBox(height: 14),
        if (basket.isEmpty)
          const InfoBox(
            icon: Icons.add_shopping_cart,
            title: 'tu lista está vacía',
            body: 'volvé a buscar productos y tocá agregar para empezar a armarla',
          )
        else ...[
          ...basket.map((line) => Card(
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
                        child: Text(
                          line.product.name,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      IconButton(
                        onPressed: () => setState(() => basket.remove(line)),
                        icon: const Icon(Icons.delete_outline),
                      ),
                    ],
                  ),
                  Text(
                    line.product.detail,
                    style: const TextStyle(color: Colors.black54, fontSize: 12),
                  ),
                  Row(
                    children: [
                      IconButton(
                        onPressed: () => quantity(line, -1),
                        icon: const Icon(Icons.remove_circle_outline),
                      ),
                      Text(
                        '${line.quantity}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        onPressed: () => quantity(line, 1),
                        icon: const Icon(Icons.add_circle_outline),
                      ),
                      const Spacer(),
                      Text(
                        money(line.product.price * line.quantity),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          )),
          Card(
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('subtotal de referencia'),
                      Text(
                        money(total),
                        style: const TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  const Text(
                    'importe ilustrativo: todavía no representa precios reales de comercios',
                    style: TextStyle(fontSize: 11, color: Colors.black54),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          FilledButton.icon(
            onPressed: () => setState(() => page = 2),
            icon: const Icon(Icons.compare_arrows),
            label: const Text('comparar mi lista'),
          ),
        ],
        OutlinedButton.icon(
          onPressed: () => setState(() => page = 0),
          icon: const Icon(Icons.add),
          label: const Text('seguir agregando productos'),
        ),
      ],
    );
  }

  Widget comparePage() {
    if (basket.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(18),
        children: const [
          InfoBox(
            icon: Icons.compare_arrows,
            title: 'todavía no hay nada para comparar',
            body: 'agregá productos a tu lista y después vas a poder ver la comparación',
          ),
        ],
      );
    }

    final stores = [
      ('supermercado norte', 1.00, 'sin descuento adicional en este ejemplo'),
      ('supermercado centro', 0.94, '6% de descuento ilustrativo aplicado'),
      ('supermercado sur', 0.97, '3% de ahorro ilustrativo por promoción'),
    ];

    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        const Text(
          'comparación de tu lista',
          style: TextStyle(fontSize: 23, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 5),
        const Text(
          'ejemplo de cálculo · no son precios ni promociones reales',
          style: TextStyle(
            color: Colors.deepOrange,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 14),
        ...stores.asMap().entries.map((entry) {
          final store = entry.value;
          final best = entry.key == 1;
          final amount = total * store.$2;

          return Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: BorderSide(
                color: best
                    ? const Color(0xFF23845F)
                    : const Color(0xFFE1E8E4),
                width: best ? 1.5 : 1,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.storefront_outlined,
                        color: Color(0xFF176B52),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          store.$1,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      if (best)
                        const Chip(
                          label: Text('menor total', style: TextStyle(fontSize: 11)),
                          visualDensity: VisualDensity.compact,
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    money(amount),
                    style: TextStyle(
                      fontSize: 25,
                      fontWeight: FontWeight.w800,
                      color: best
                          ? const Color(0xFF176B52)
                          : Colors.black87,
                    ),
                  ),
                  Text(
                    store.$3,
                    style: const TextStyle(color: Colors.black54, fontSize: 12),
                  ),
                ],
              ),
            ),
          );
        }),
        const SizedBox(height: 8),
        const InfoBox(
          icon: Icons.verified_outlined,
          title: 'para comparar en serio',
          body: 'hay que conectar precios y promociones verificadas de cada comercio, sucursales, medios de pago, topes, vigencias y condiciones. hasta entonces esta pantalla usa datos ficticios y no recomienda una compra real',
        ),
      ],
    );
  }
}

class InfoBox extends StatelessWidget {
  const InfoBox({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

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
                Text(
                  body,
                  style: const TextStyle(
                    color: Colors.black54,
                    height: 1.35,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
