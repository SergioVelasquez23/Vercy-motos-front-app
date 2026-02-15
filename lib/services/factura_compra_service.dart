import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/factura_compra.dart';
import '../models/ingrediente.dart';

class FacturaCompraService {
  final ApiConfig _apiConfig = ApiConfig.instance;

  String get baseUrl => '${_apiConfig.baseUrl}/api/facturas-compras';

  Map<String, String> get headers => _apiConfig.getSecureHeaders();

  Future<List<FacturaCompra>> getFacturasCompras() async {
    try {
      final response = await http.get(Uri.parse(baseUrl), headers: headers);

      if (response.statusCode == 200) {
        final responseBody = response.body;
        if (responseBody.isEmpty) {
            
          return [];
        }

        final dynamic jsonData = json.decode(responseBody);
          

        List<dynamic> dataList;

        // Manejar diferentes tipos de respuesta del servidor
        if (jsonData is List) {
          // Si el servidor devuelve directamente una lista
          dataList = jsonData;
                     } else if (jsonData is Map<String, dynamic>) {
          // Si el servidor devuelve un objeto con campo 'data'
          if (jsonData.containsKey('data')) {
            final data = jsonData['data'];
            if (data is List) {
              dataList = data;
            } else {
                
              throw Exception('El campo data no contiene una lista válida');
            }
          } else {
              
            throw Exception(
              'Respuesta del servidor no tiene el formato esperado',
            );
          }
        } else {
            
          throw Exception('Formato de respuesta del servidor no válido');
        }

        // Convertir la lista a objetos FacturaCompra
        final facturas = <FacturaCompra>[];
        for (int i = 0; i < dataList.length; i++) {
          try {
            final facturaJson = dataList[i];
            if (facturaJson is Map<String, dynamic>) {
              facturas.add(FacturaCompra.fromJson(facturaJson));
            } else {
                             }
          } catch (e) {
              
          }
        }

          

        // Ordenar facturas por fecha descendente (más recientes primero)
        facturas.sort((a, b) => b.fechaCreacion.compareTo(a.fechaCreacion));

        return facturas;
      } else {
        final errorMessage =
            'Error al cargar facturas de compras: ${response.statusCode}';
          
          
        throw Exception(errorMessage);
      }
    } catch (e) {
        
      throw Exception('Error de conexión: $e');
    }
  }

  Future<FacturaCompra> getFacturaCompra(String id) async {
    try {
        
      final response = await http.get(
        Uri.parse('$baseUrl/$id'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final responseBody = response.body;
        if (responseBody.isEmpty) {
          throw Exception('Respuesta vacía del servidor');
        }

        final dynamic jsonData = json.decode(responseBody);

        Map<String, dynamic> facturaData;

        if (jsonData is Map<String, dynamic>) {
          if (jsonData.containsKey('data')) {
            facturaData = jsonData['data'];
          } else {
            facturaData = jsonData;
          }
        } else {
          throw Exception(
            'Formato de respuesta no válido para factura individual',
          );
        }

        return FacturaCompra.fromJson(facturaData);
      } else {
        throw Exception(
          'Error al cargar factura de compra: ${response.statusCode}',
        );
      }
    } catch (e) {
        
      throw Exception('Error de conexión: $e');
    }
  }

  Future<List<FacturaCompra>> getFacturasPorProveedor(
    String proveedorNit,
  ) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/proveedor/$proveedorNit'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonResponse = json.decode(response.body);
        final List<dynamic> data = jsonResponse['data'] ?? [];
        final facturas = data
            .map((json) => FacturaCompra.fromJson(json))
            .toList();

        // Ordenar facturas por fecha descendente (más recientes primero)
        facturas.sort((a, b) => b.fechaCreacion.compareTo(a.fechaCreacion));

        return facturas;
      } else {
        throw Exception(
          'Error al cargar facturas del proveedor: ${response.statusCode}',
        );
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }

  Future<String> generarNumeroFactura() async {
    try {
        
        

      final response = await http.get(
        Uri.parse('$baseUrl/numero-factura'),
        headers: headers,
      );
      if (response.statusCode == 200) {
        final responseBody = response.body;
        if (responseBody.isEmpty) {
          throw Exception(
            'Respuesta vacía del servidor para número de factura',
          );
        }

        final dynamic jsonData = json.decode(responseBody);
          

        String numeroFactura = '';

        if (jsonData is Map<String, dynamic>) {
          // Verificar si hay error en la respuesta
          if (jsonData.containsKey('success') && jsonData['success'] == false) {
            final errorMessage =
                jsonData['message'] ?? 'Error desconocido al generar número';
              
            throw Exception(errorMessage);
          }

          // Intentar obtener el número de diferentes posibles campos
          if (jsonData.containsKey('numeroFactura')) {
            numeroFactura = jsonData['numeroFactura']?.toString() ?? '';
          } else if (jsonData.containsKey('data') && jsonData['data'] != null) {
            final data = jsonData['data'];
            if (data is Map<String, dynamic> &&
                data.containsKey('numeroFactura')) {
              numeroFactura = data['numeroFactura']?.toString() ?? '';
            } else if (data is String) {
              numeroFactura = data;
            }
          } else if (jsonData.containsKey('numero')) {
            numeroFactura = jsonData['numero']?.toString() ?? '';
          }

          if (numeroFactura.isEmpty) {
              
              
            throw Exception(
              'No se encontró número de factura en la respuesta del servidor',
            );
          }
        } else if (jsonData is String) {
          numeroFactura = jsonData;
        } else {
          throw Exception(
            'Formato de respuesta no válido para número de factura',
          );
        }

          
        return numeroFactura;
      } else {
        final errorMessage =
            'Error al generar número de factura: ${response.statusCode}';
          
          
        throw Exception(errorMessage);
      }
    } catch (e) {
        
      throw Exception('Error de conexión: $e');
    }
  }

  Future<List<Ingrediente>> getIngredientesDisponibles() async {
    try {
        
      final response = await http.get(
        Uri.parse('$baseUrl/ingredientes'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final responseBody = response.body;
        if (responseBody.isEmpty) {
            
          return [];
        }

        final dynamic jsonData = json.decode(responseBody);
          

        List<dynamic> dataList;

        // Manejar diferentes tipos de respuesta del servidor
        if (jsonData is List) {
          // Si el servidor devuelve directamente una lista
          dataList = jsonData;
        } else if (jsonData is Map<String, dynamic>) {
          // Si el servidor devuelve un objeto con campo 'data'
          if (jsonData.containsKey('data')) {
            final data = jsonData['data'];
            if (data is List) {
              dataList = data;
                             } else {
              throw Exception(
                'El campo data de ingredientes no contiene una lista válida',
              );
            }
          } else {
              
            throw Exception(
              'Respuesta de ingredientes no tiene el formato esperado',
            );
          }
        } else {
          throw Exception('Formato de respuesta de ingredientes no válido');
        }

        // Convertir la lista a objetos Ingrediente
        final ingredientes = <Ingrediente>[];
        for (int i = 0; i < dataList.length; i++) {
          try {
            final ingredienteJson = dataList[i];
            if (ingredienteJson is Map<String, dynamic>) {
              ingredientes.add(Ingrediente.fromJson(ingredienteJson));
            } else {
                             }
          } catch (e) {
              
          }
        }

          
        return ingredientes;
      } else {
        final errorMessage =
            'Error al cargar ingredientes: ${response.statusCode}';
          
          
        throw Exception(errorMessage);
      }
    } catch (e) {
        
      throw Exception('Error de conexión: $e');
    }
  }

  Future<FacturaCompra> crearFacturaCompra(FacturaCompra facturaCompra) async {
    try {
         
      // Verificar si hay items
      if (facturaCompra.items.isEmpty) {
          
      } else {
          
        for (var i = 0; i < facturaCompra.items.length; i++) {
          final item = facturaCompra.items[i];
        }
      }

      // Recalcular el total para asegurarnos de que sea correcto
      double calculatedTotal = facturaCompra.items.fold<double>(
        0,
        (sum, item) => sum + item.subtotal,
      );

      // El modelo ya maneja automáticamente no incluir el ID si es null o vacío
      final facturaJson = facturaCompra.toJson();

      // Verificar que los items estén presentes en el JSON
      var itemsIngredientes = facturaJson['itemsIngredientes'] as List<dynamic>;
      if (itemsIngredientes.isEmpty && facturaCompra.items.isNotEmpty) {
        // Intentar reconstruir los items manualmente
        facturaJson['itemsIngredientes'] = facturaCompra.items
            .map(
              (item) => {
                'ingredienteId': item.ingredienteId,
                'ingredienteNombre': item.ingredienteNombre,
                'cantidad': item.cantidad,
                'unidad': item.unidad,
                'precioUnitario': item.precioUnitario,
                'precioTotal': item.subtotal,
                'subtotal': item.subtotal,
                'descontable': true,
                'observaciones': '',
                // 📦 Campos de destino
                'destino': item.destino,
                'cantidadAlmacen': item.cantidadAlmacen,
                'cantidadBodega': item.cantidadBodega,
              },
            )
            .toList();
      }

      // Verificar que el total está presente en el JSON
      if (facturaJson['total'] == 0 && calculatedTotal > 0) {
        facturaJson['total'] = calculatedTotal;
      }

        
        
        
        
        

      final response = await http.post(
        Uri.parse('$baseUrl/crear'),
        headers: headers,
        body: json.encode(facturaJson),
      );
      
      if (response.statusCode == 201 || response.statusCode == 200) {
        final responseBody = response.body;
        if (responseBody.isEmpty) {
          throw Exception('Respuesta vacía del servidor al crear factura');
        }

        final dynamic jsonData = json.decode(responseBody);
          
          

        if (jsonData is Map<String, dynamic>) {
          // Verificar si la respuesta indica éxito
          if (jsonData.containsKey('success') && jsonData['success'] == false) {
            final errorMessage =
                jsonData['message'] ?? 'Error desconocido al crear factura';
              
            throw Exception(errorMessage);
          }

          // Intentar obtener los datos de la factura creada
          Map<String, dynamic>? facturaData;

          // El backend devuelve la factura en el campo 'factura'
          if (jsonData.containsKey('factura') && jsonData['factura'] != null) {
            facturaData = jsonData['factura'];
              

            // Validar que la factura tenga los items y el total correcto
            if (facturaData!['itemsIngredientes'] is List &&
                (facturaData['itemsIngredientes'] as List).isEmpty &&
                facturaJson.containsKey('itemsIngredientes') &&
                (facturaJson['itemsIngredientes'] as List).isNotEmpty) {
                                  
              // Copiar los items enviados a la respuesta
              facturaData['itemsIngredientes'] =
                  facturaJson['itemsIngredientes'];
              facturaData['total'] = calculatedTotal;
            }

            // Si el total es 0 pero calculamos uno diferente, corregirlo
            if (facturaData['total'] == 0.0 && calculatedTotal > 0) {
              facturaData['total'] = calculatedTotal;
            }
          } else if (jsonData.containsKey('data') && jsonData['data'] != null) {
            facturaData = jsonData['data'];
              
          } else if (jsonData.containsKey('success') &&
              jsonData['success'] == true) {
            // Si hay success=true pero no data, puede que los datos estén en el nivel raíz
            facturaData = Map<String, dynamic>.from(jsonData);
            facturaData.remove('success');
            facturaData.remove('message');
            facturaData.remove(
              'numeroFactura',
            ); // El numero se incluye separado
              
          } else {
            // Si no hay campo 'data' ni 'success', asumir que toda la respuesta son los datos
            facturaData = jsonData;
              
          }

          if (facturaData == null || facturaData.isEmpty) {
            throw Exception(
              'No se encontraron datos de la factura creada en la respuesta',
            );
          }

            
            

          // Crear objeto FacturaCompra con los items y total calculado explícitamente
          final facturaCreada = FacturaCompra.fromJson(facturaData);

          // Verificación final
          if (facturaCreada.total == 0 && calculatedTotal > 0) {
            // Crear manualmente un nuevo objeto con el total correcto
            return FacturaCompra(
              id: facturaCreada.id,
              numeroFactura: facturaCreada.numeroFactura,
              proveedorNit: facturaCreada.proveedorNit,
              proveedorNombre: facturaCreada.proveedorNombre,
              fechaFactura: facturaCreada.fechaFactura,
              fechaVencimiento: facturaCreada.fechaVencimiento,
              total: calculatedTotal, // Usar el calculado explícitamente
              estado: facturaCreada.estado,
              pagadoDesdeCaja: facturaCreada.pagadoDesdeCaja,
              items: facturaCompra.items, // Usar los items originales
              fechaCreacion: facturaCreada.fechaCreacion,
              fechaActualizacion: facturaCreada.fechaActualizacion,
            );
          }

          return facturaCreada;
        } else {
          throw Exception(
            'Formato de respuesta no válido al crear factura: ${jsonData.runtimeType}',
          );
        }
      } else {
        // Intentar parsear el mensaje de error
        String errorMessage =
            'Error al crear factura de compra: ${response.statusCode}';
        try {
          final errorBody = json.decode(response.body);
          if (errorBody is Map<String, dynamic> &&
              errorBody.containsKey('message')) {
            errorMessage = errorBody['message'];
          }
        } catch (parseError) {
            
            
        }

          
        throw Exception(errorMessage);
      }
    } catch (e) {
        
      if (e is Exception) {
        rethrow;
      }
      throw Exception('Error de conexión: $e');
    }
  }

  // Nuevos métodos para filtros específicos
  Future<List<FacturaCompra>> getFacturasPagadasDesdeCaja() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/pagadas-desde-caja'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonResponse = json.decode(response.body);
        final List<dynamic> data = jsonResponse['data'] ?? [];
        final facturas = data
            .map((json) => FacturaCompra.fromJson(json))
            .toList();

        // Ordenar facturas por fecha descendente (más recientes primero)
        facturas.sort((a, b) => b.fechaCreacion.compareTo(a.fechaCreacion));

        return facturas;
      } else {
        throw Exception(
          'Error al cargar facturas pagadas desde caja: ${response.statusCode}',
        );
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }

  Future<List<FacturaCompra>> getFacturasNoPagadasDesdeCaja() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/no-pagadas-desde-caja'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonResponse = json.decode(response.body);
        final List<dynamic> data = jsonResponse['data'] ?? [];
        final facturas = data
            .map((json) => FacturaCompra.fromJson(json))
            .toList();

        // Ordenar facturas por fecha descendente (más recientes primero)
        facturas.sort((a, b) => b.fechaCreacion.compareTo(a.fechaCreacion));

        return facturas;
      } else {
        throw Exception(
          'Error al cargar facturas no pagadas desde caja: ${response.statusCode}',
        );
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }

  Future<Map<String, dynamic>> getResumenPagoCaja() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/resumen-pago-caja'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonResponse = json.decode(response.body);
        return jsonResponse['data'] ?? {};
      } else {
        throw Exception(
          'Error al cargar resumen de pago caja: ${response.statusCode}',
        );
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }

  // Método de debugging para probar la conectividad del backend
  Future<Map<String, dynamic>> debugBackendConnection() async {
    final result = <String, dynamic>{
      'baseUrl': baseUrl,
      'headers': headers,
      'tests': <String, dynamic>{},
    };

      
      

    // Test 1: Probar endpoint de número de factura
    try {
        
      final numeroResponse = await http.get(
        Uri.parse('$baseUrl/numero-factura'),
        headers: headers,
      );

      result['tests']['numero_factura'] = {
        'status': numeroResponse.statusCode,
        'body': numeroResponse.body,
        'success': numeroResponse.statusCode == 200,
      };

        
    } catch (e) {
      result['tests']['numero_factura'] = {
        'status': 'ERROR',
        'error': e.toString(),
        'success': false,
      };
        
    }

    // Test 2: Probar endpoint de listado de facturas
    try {
        
      final listResponse = await http.get(Uri.parse(baseUrl), headers: headers);

      result['tests']['list_facturas'] = {
        'status': listResponse.statusCode,
        'body_length': listResponse.body.length,
        'success': listResponse.statusCode == 200,
      };

        
    } catch (e) {
      result['tests']['list_facturas'] = {
        'status': 'ERROR',
        'error': e.toString(),
        'success': false,
      };
        
    }

    // Test 3: Probar endpoint de creación (con datos de prueba)
    try {
        
      // Solo probamos la respuesta del endpoint sin datos válidos
      final createResponse = await http.post(
        Uri.parse('$baseUrl/crear'),
        headers: headers,
        body: json.encode({}), // Datos vacíos para probar respuesta
      );

      result['tests']['create_endpoint'] = {
        'status': createResponse.statusCode,
        'body': createResponse.body,
        'reachable': true,
      };

        
    } catch (e) {
      result['tests']['create_endpoint'] = {
        'status': 'ERROR',
        'error': e.toString(),
        'reachable': false,
      };
        
    }

      
    return result;
  }

  /// Eliminar factura de compra (con reversión automática de stock y dinero)
  Future<Map<String, dynamic>> eliminarFacturaCompra(String id) async {
    try {
        

      final response = await http.delete(
        Uri.parse('$baseUrl/$id'),
        headers: headers,
      );

        
        

      if (response.statusCode == 204 || response.statusCode == 200) {
        // El backend maneja automáticamente:
        // - Reversión de stock de productos/ingredientes
        // - Reversión de dinero del cuadre de caja
        // - Registro en historial de ediciones

          

        // Intentar parsear la respuesta para obtener detalles de la reversión
        Map<String, dynamic> result = {
          'success': true,
          'message': 'Factura eliminada correctamente',
          'stockRevertido': true,
          'dineroRevertido': true,
        };

        try {
          if (response.statusCode == 200 && response.body.isNotEmpty) {
            final responseData = json.decode(response.body);
            if (responseData is Map<String, dynamic>) {
              // Si hay datos de reversión, agregarlos al resultado
              if (responseData.containsKey('stockRevertido')) {
                result['stockRevertido'] = responseData['stockRevertido'];
              }
              if (responseData.containsKey('dineroRevertido')) {
                result['dineroRevertido'] = responseData['dineroRevertido'];
              }
              if (responseData.containsKey('message')) {
                result['message'] = responseData['message'];
              }
              if (responseData.containsKey('detallesReversion')) {
                result['detallesReversion'] = responseData['detallesReversion'];
              }
            }
          }
        } catch (parseError) {
                     }

        return result;
      } else {
        // Intentar obtener mensaje de error del backend
        String errorMsg = 'Error al eliminar factura: ${response.statusCode}';

        try {
          final errorData = json.decode(response.body);
          if (errorData['message'] != null) {
            errorMsg = errorData['message'];
          }
        } catch (_) {
          // Usar mensaje genérico si no se puede parsear
        }

        throw Exception(errorMsg);
      }
    } catch (e) {
        
      throw Exception('Error de conexión: $e');
    }
  }

  /// Anular factura de compra (alternativa a eliminación para auditoría)
  Future<Map<String, dynamic>> anularFacturaCompra(
    String id,
    String motivoAnulacion,
  ) async {
    try {
        

      final response = await http.patch(
        Uri.parse('$baseUrl/$id/anular'),
        headers: headers,
        body: json.encode({'motivoAnulacion': motivoAnulacion}),
      );

        
        

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);

        // Manejar respuesta con wrapper de éxito
        Map<String, dynamic> facturaData;
        if (responseData is Map<String, dynamic> &&
            responseData['success'] == true &&
            responseData['data'] != null) {
          facturaData = responseData['data'] as Map<String, dynamic>;
        } else if (responseData is Map<String, dynamic>) {
          facturaData = responseData;
        } else {
          throw Exception('Formato de respuesta inválido');
        }

        // Crear FacturaCompra desde los datos recibidos
        final facturaAnulada = FacturaCompra.fromJson(facturaData);

        // Preparar resultado con datos de reversión
        Map<String, dynamic> result = {
          'success': true,
          'message': 'Factura anulada correctamente',
          'stockRevertido': true,
          'dineroRevertido': facturaAnulada.pagadoDesdeCaja,
          'factura': facturaAnulada,
        };

        // Si la respuesta tiene detalles adicionales de reversión
        if (responseData.containsKey('stockRevertido')) {
          result['stockRevertido'] = responseData['stockRevertido'];
        }
        if (responseData.containsKey('dineroRevertido')) {
          result['dineroRevertido'] = responseData['dineroRevertido'];
        }
        if (responseData.containsKey('message')) {
          result['message'] = responseData['message'];
        }
        if (responseData.containsKey('detallesReversion')) {
          result['detallesReversion'] = responseData['detallesReversion'];
        }

          
        return result;
      } else {
        // Intentar obtener mensaje de error del backend
        String errorMsg = 'Error al anular factura: ${response.statusCode}';

        try {
          final errorData = json.decode(response.body);
          if (errorData['message'] != null) {
            errorMsg = errorData['message'];
          }
        } catch (_) {
          // Usar mensaje genérico si no se puede parsear
        }

        throw Exception(errorMsg);
      }
    } catch (e) {
        
      throw Exception('Error de conexión: $e');
    }
  }
}
