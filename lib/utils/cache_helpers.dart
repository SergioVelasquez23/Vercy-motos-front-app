// Utilidades para manejo inteligente de caché
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/datos_cache_provider.dart';

class CacheHelpers {
  /// Actualizar datos después de una operación crítica (crear, editar, eliminar)
  static Future<void> refreshAfterCriticalOperation(
    BuildContext context, {
    bool refreshProductos = true,
    bool refreshCategorias = false,
    bool refreshIngredientes = false,
  }) async {
    final provider = Provider.of<DatosCacheProvider>(context, listen: false);

    print('🔄 Actualizando caché después de operación crítica...');

    if (refreshProductos) {
      await provider.forceRefreshProductos();
    }

    if (refreshCategorias || refreshIngredientes) {
      await provider.forceRefresh();
    }
  }

  /// Mostrar indicador de última actualización en UI
  static Widget buildCacheStatus(BuildContext context) {
    return Consumer<DatosCacheProvider>(
      builder: (context, provider, child) {
        final ultimaActualizacion = provider.ultimaActualizacion;

        if (ultimaActualizacion == null) {
          return Container(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Text(
              'Sin datos en caché',
              style: TextStyle(color: Colors.orange, fontSize: 10),
            ),
          );
        }

        final diferencia = DateTime.now().difference(ultimaActualizacion);
        String tiempo;
        Color color;

        if (diferencia.inMinutes < 1) {
          tiempo = 'Hace ${diferencia.inSeconds}s';
          color = Colors.green;
        } else if (diferencia.inMinutes < 5) {
          tiempo = 'Hace ${diferencia.inMinutes}min';
          color = Colors.green;
        } else if (diferencia.inMinutes < 15) {
          tiempo = 'Hace ${diferencia.inMinutes}min';
          color = Colors.orange;
        } else {
          tiempo = 'Hace ${diferencia.inMinutes}min';
          color = Colors.red;
        }

        return Container(
          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.sync, size: 12, color: color),
              SizedBox(width: 4),
              Text(tiempo, style: TextStyle(color: color, fontSize: 10)),
            ],
          ),
        );
      },
    );
  }

  /// Mostrar botón de refresh manual
  static Widget buildRefreshButton(
    BuildContext context, {
    VoidCallback? onPressed,
  }) {
    return Consumer<DatosCacheProvider>(
      builder: (context, provider, child) {
        return IconButton(
          onPressed:
              onPressed ??
              () async {
                await provider.forceRefresh();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Datos actualizados'),
                    backgroundColor: Colors.green,
                    duration: Duration(seconds: 2),
                  ),
                );
              },
          icon: Icon(Icons.refresh),
          tooltip: 'Actualizar datos',
        );
      },
    );
  }

  /// Verificar si necesita mostrar warning de datos desactualizados
  static bool shouldShowOutdatedWarning(DatosCacheProvider provider) {
    return provider.productosExpired ||
        provider.categoriasExpired;
  }
}
