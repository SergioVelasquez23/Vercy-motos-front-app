import 'package:flutter/material.dart';
import 'providers/datos_cache_provider.dart';

void main() {
  runApp(const TestCacheApp());
}

class TestCacheApp extends StatelessWidget {
  const TestCacheApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Test Cache Provider',
      home: const TestCacheScreen(),
    );
  }
}

class TestCacheScreen extends StatefulWidget {
  const TestCacheScreen({Key? key}) : super(key: key);

  @override
  State<TestCacheScreen> createState() => _TestCacheScreenState();
}

class _TestCacheScreenState extends State<TestCacheScreen> {
  late DatosCacheProvider cacheProvider;
  int rebuilds = 0;

  @override
  void initState() {
    super.initState();
    cacheProvider = DatosCacheProvider();
    cacheProvider.addListener(_onCacheUpdate);
    cacheProvider.initialize();
  }

  void _onCacheUpdate() {
    setState(() {
      rebuilds++;
    });
    print('🔔 UI rebuild #$rebuilds triggered by cache update');
  }

  @override
  void dispose() {
    cacheProvider.removeListener(_onCacheUpdate);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Cache Test - Rebuilds: $rebuilds'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () async {
              print('🔄 Manual refresh requested');
              await cacheProvider.forceRefresh();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Card(
            child: ListTile(
              title: const Text('Cache Status'),
              subtitle: Text(
                'Productos: ${cacheProvider.productos?.length ?? 0}\n'
                'Categorías: ${cacheProvider.categorias?.length ?? 0}\n'
                'Ingredientes: ${cacheProvider.ingredientes?.length ?? 0}\n'
                'Rebuilds: $rebuilds',
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: cacheProvider.productos?.length ?? 0,
              itemBuilder: (context, index) {
                final producto = cacheProvider.productos![index];
                return ListTile(
                  title: Text(producto.nombre),
                  subtitle: Text('\$${producto.precio}'),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
