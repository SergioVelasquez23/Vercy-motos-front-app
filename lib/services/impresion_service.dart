import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../utils/api_error.dart';
import '../utils/currency_utils.dart';

class ImpresionService {
  // Generar resumen de impresión para pedido
  Future<Map<String, dynamic>?> generarResumenPedido(String pedidoId) async {
    try {
        

      final response = await http.get(
        Uri.parse(
          '${ApiConfig().baseUrl}/api/facturas/resumen-impresion/$pedidoId',
        ),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
          
        return data;
      } else if (response.statusCode == 404) {
          
        return null;
      } else {
          
        throwBackendError(response.body, response.statusCode, prefix: 'Error del servidor');
      }
    } catch (e) {
        
      throw Exception('Error generando resumen: $e');
    }
  }

  // Crear factura desde pedido
  Future<Map<String, dynamic>?> crearFacturaDesdepedido(
    String pedidoId, {
    String? nit,
    String? clienteNombre,
    String? clienteCorreo,
    String? clienteTelefono,
    String? clienteDireccion,
    String medioPago = 'Efectivo',
  }) async {
    try {
        

      final Map<String, dynamic> datos = {
        'nit': nit ?? '22222222222',
        'clienteNombre': clienteNombre ?? '',
        'clienteCorreo': clienteCorreo ?? '',
        'clienteTelefono': clienteTelefono ?? '',
        'clienteDireccion': clienteDireccion ?? '',
        'medioPago': medioPago,
      };

      final response = await http.post(
        Uri.parse('${ApiConfig().baseUrl}/api/facturas/desde-pedido/$pedidoId'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode(datos),
      );

      if (response.statusCode == 201) {
        final data = json.decode(response.body);
          
        return data;
      } else if (response.statusCode == 404) {
          
        return null;
      } else {
          
        throwBackendError(response.body, response.statusCode, prefix: 'Error del servidor');
      }
    } catch (e) {
        
      throw Exception('Error creando factura: $e');
    }
  }

  // Obtener factura para impresión
  Future<Map<String, dynamic>?> obtenerFacturaParaImpresion(
    String facturaId,
  ) async {
    try {
        

      final response = await http.get(
        Uri.parse(
          '${ApiConfig().baseUrl}/api/facturas/factura-impresion/$facturaId',
        ),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
          
        return data;
      } else if (response.statusCode == 404) {
          
        return null;
      } else {
          
        throwBackendError(response.body, response.statusCode, prefix: 'Error del servidor');
      }
    } catch (e) {
        
      throw Exception('Error obteniendo factura: $e');
    }
  }

  // Generar texto para compartir/imprimir
  String generarTextoImpresion(
    Map<String, dynamic> resumen, {
    bool esFactura = false,
  }) {
    final StringBuffer texto = StringBuffer();

    try {
      // Encabezado
      texto.writeln('=====================================');
      texto.writeln(
        '         ${resumen['nombreRestaurante'] ?? 'SOPA Y CARBÓN'}',
      );
      texto.writeln(
        '  ${resumen['direccionRestaurante'] ?? 'Dirección del restaurante'}',
      );
      texto.writeln('  Tel: ${resumen['telefonoRestaurante'] ?? 'Teléfono'}');
      texto.writeln('=====================================');
      texto.writeln();

      if (esFactura) {
        // Información de factura
        texto.writeln('FACTURA: ${resumen['numero'] ?? 'N/A'}');
        texto.writeln('NIT: ${resumen['nit'] ?? '22222222222'}');

        // Información del cliente
        if (resumen['clienteNombre'] != null &&
            resumen['clienteNombre'].toString().isNotEmpty) {
          texto.writeln('Cliente: ${resumen['clienteNombre']}');
        }
        if (resumen['clienteCorreo'] != null &&
            resumen['clienteCorreo'].toString().isNotEmpty) {
          texto.writeln('Email: ${resumen['clienteCorreo']}');
        }
        if (resumen['clienteTelefono'] != null &&
            resumen['clienteTelefono'].toString().isNotEmpty) {
          texto.writeln('Teléfono: ${resumen['clienteTelefono']}');
        }
        if (resumen['clienteDireccion'] != null &&
            resumen['clienteDireccion'].toString().isNotEmpty) {
          texto.writeln('Dirección: ${resumen['clienteDireccion']}');
        }
        texto.writeln('Atendió: ${resumen['atendidoPor'] ?? 'N/A'}');
      } else {
        // Información de pedido (SIN mostrar el ID de MongoDB)
        texto.writeln('Mesa: ${resumen['mesa'] ?? 'N/A'}');
        texto.writeln('Mesero: ${resumen['mesero'] ?? 'N/A'}');
        texto.writeln('Tipo: ${resumen['tipo'] ?? 'Normal'}');
      }

      texto.writeln('Fecha: ${resumen['fecha']} ${resumen['hora']}');
      texto.writeln();

      // Detalle de productos
      texto.writeln('-------------------------------------');
      texto.writeln('DETALLE:');
      texto.writeln('-------------------------------------');

      final List<dynamic> productos = resumen['detalleProductos'] ?? [];
      double totalGeneral = 0.0;

      for (var producto in productos) {
        int cantidad = producto['cantidad'] ?? 1;
        String nombre = producto['nombre'] ?? 'Producto';
        double precio =
            (producto['precioUnitario'] ?? producto['precio'] ?? 0.0)
                .toDouble();
        double subtotal = (producto['subtotal'] ?? (cantidad * precio))
            .toDouble();

        texto.writeln('${cantidad}x $nombre');
        texto.writeln(
          '    @${CurrencyUtils.format(precio)} = ${CurrencyUtils.format(subtotal)}',
        );

        // Observaciones si existen
        if (producto['observaciones'] != null &&
            producto['observaciones'].toString().isNotEmpty) {
          texto.writeln('    Obs: ${producto['observaciones']}');
        }

        // Ingredientes (solo para pedidos)
        if (!esFactura && producto['ingredientes'] != null) {
          final List<dynamic> ingredientes = producto['ingredientes'];
          if (ingredientes.isNotEmpty) {
            texto.writeln('    Ingredientes:');
            for (var ingrediente in ingredientes) {
              texto.writeln(
                '    - ${ingrediente['nombre']}: ${ingrediente['cantidad']} ${ingrediente['unidad']}',
              );
            }
          }
        }

        texto.writeln();
        totalGeneral += subtotal;
      }

      // Total
      texto.writeln('-------------------------------------');
      texto.writeln('TOTAL: ${CurrencyUtils.format(totalGeneral)}');

      if (esFactura) {
        texto.writeln('Forma de pago: ${resumen['medioPago'] ?? 'Efectivo'}');
        if (resumen['formaPago'] != null) {
          texto.writeln('Método: ${resumen['formaPago']}');
        }
      }

      texto.writeln('=====================================');
      texto.writeln('       ¡GRACIAS POR SU VISITA!');
      texto.writeln('=====================================');
    } catch (e) {
        
      return 'Error generando el documento de impresión';
    }

    return texto.toString();
  }

  // Formatear resumen para mostrar en UI
  Map<String, dynamic> formatearResumenParaUI(Map<String, dynamic> resumen) {
    try {
      final Map<String, dynamic> resumenFormateado = {
        'encabezado': {
          'restaurante': resumen['nombreRestaurante'] ?? 'Sopa y Carbón',
          'direccion':
              resumen['direccionRestaurante'] ?? 'Dirección del restaurante',
          'telefono':
              resumen['telefonoRestaurante'] ?? 'Teléfono del restaurante',
        },
        'documento': {
          'tipo': resumen.containsKey('numero') ? 'Factura' : 'Pedido',
          'numero': resumen['numero'] ?? resumen['pedidoId'] ?? 'N/A',
          'fecha': '${resumen['fecha']} ${resumen['hora']}',
        },
        'cliente': {},
        'productos': [],
        'total': (resumen['total'] ?? 0.0).toDouble(),
      };

      // Información específica según tipo
      if (resumen.containsKey('numero')) {
        // Es factura
        resumenFormateado['cliente'] = {
          'nit': resumen['nit'] ?? '22222222222',
          'telefono': resumen['clienteTelefono'] ?? '',
          'direccion': resumen['clienteDireccion'] ?? '',
          'atendidoPor': resumen['atendidoPor'] ?? '',
        };
      } else {
        // Es pedido
        resumenFormateado['cliente'] = {
          'mesa': resumen['mesa'] ?? 'N/A',
          'mesero': resumen['mesero'] ?? 'N/A',
          'tipo': resumen['tipo'] ?? 'Normal',
        };
      }

      // Formatear productos
      final List<dynamic> productos = resumen['detalleProductos'] ?? [];
      for (var producto in productos) {
        resumenFormateado['productos'].add({
          'cantidad': producto['cantidad'] ?? 1,
          'nombre': producto['nombre'] ?? 'Producto',
          'precio': (producto['precioUnitario'] ?? producto['precio'] ?? 0.0)
              .toDouble(),
          'subtotal': (producto['subtotal'] ?? 0.0).toDouble(),
          'observaciones': producto['observaciones'] ?? '',
          'ingredientes': producto['ingredientes'] ?? [],
        });
      }

      return resumenFormateado;
    } catch (e) {
        
      return {
        'error': 'Error procesando la información',
        'total': 0.0,
        'productos': [],
      };
    }
  }

  /// Limpia el resumen de los IDs de MongoDB para mostrar solo información relevante al usuario
  Map<String, dynamic> limpiarResumenParaVisualizacion(
    Map<String, dynamic> resumen,
  ) {
    // Crear una copia del resumen original
    Map<String, dynamic> resumenLimpio = Map<String, dynamic>.from(resumen);

    // Lista de campos que contienen IDs de MongoDB que queremos ocultar
    List<String> camposAEliminar = [
      '_id',
      'pedidoId',
      'id',
      'mongo_id',
      'mongoId',
      'objectId',
    ];

    // Eliminar campos de ID del nivel superior
    for (String campo in camposAEliminar) {
      resumenLimpio.remove(campo);
    }

    // Limpiar productos si existen
    if (resumenLimpio['productos'] is List) {
      List<dynamic> productosLimpios = [];
      for (var producto in (resumenLimpio['productos'] as List)) {
        if (producto is Map<String, dynamic>) {
          Map<String, dynamic> productoLimpio = Map<String, dynamic>.from(
            producto,
          );
          // Eliminar IDs de los productos
          for (String campo in camposAEliminar) {
            productoLimpio.remove(campo);
          }
          productosLimpios.add(productoLimpio);
        } else {
          productosLimpios.add(producto);
        }
      }
      resumenLimpio['productos'] = productosLimpios;
    }

    // Generar un número de pedido más amigable para mostrar al usuario
    // Usar timestamp o número secuencial en lugar del ID de MongoDB
    if (!resumenLimpio.containsKey('numeroPedido')) {
      // Si tenemos fecha y hora, generar un número basado en el timestamp
      String fecha = resumenLimpio['fecha'] ?? '';
      String hora = resumenLimpio['hora'] ?? '';

      if (fecha.isNotEmpty && hora.isNotEmpty) {
        try {
          // Extraer números de la fecha y hora para crear un identificador más amigable
          String fechaNumeros = fecha.replaceAll(RegExp(r'[^0-9]'), '');
          String horaNumeros = hora.replaceAll(RegExp(r'[^0-9]'), '');

          if (fechaNumeros.length >= 6 && horaNumeros.length >= 4) {
            // Formato: DDMMAA-HHMM (ej: 251224-1430)
            String dia = fechaNumeros.substring(0, 2);
            String mes = fechaNumeros.substring(2, 4);
            String anio = fechaNumeros.substring(4, 6);
            String horaMins = horaNumeros.substring(0, 4);

            resumenLimpio['numeroPedido'] = '$dia$mes$anio-$horaMins';
          } else {
            // Fallback: usar timestamp actual
            resumenLimpio['numeroPedido'] = DateTime.now()
                .millisecondsSinceEpoch
                .toString()
                .substring(8);
          }
        } catch (e) {
          // Fallback: usar timestamp actual
          resumenLimpio['numeroPedido'] = DateTime.now().millisecondsSinceEpoch
              .toString()
              .substring(8);
        }
      } else {
        // Fallback: usar timestamp actual
        resumenLimpio['numeroPedido'] = DateTime.now().millisecondsSinceEpoch
            .toString()
            .substring(8);
      }
    }

      
    return resumenLimpio;
  }
}
