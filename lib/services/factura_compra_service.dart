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
      print('🔍 Obteniendo facturas de compras...');
      final response = await http.get(Uri.parse(baseUrl), headers: headers);

      print('📡 Response status: ${response.statusCode}');
      print('📄 Response body: ${response.body}');

      if (response.statusCode == 200) {
        final responseBody = response.body;
        if (responseBody.isEmpty) {
          print('⚠️ Response body vacío');
          return [];
        }

        final dynamic jsonData = json.decode(responseBody);
        print('📊 Tipo de datos recibidos: ${jsonData.runtimeType}');

        List<dynamic> dataList;

        // Manejar diferentes tipos de respuesta del servidor
        if (jsonData is List) {
          // Si el servidor devuelve directamente una lista
          dataList = jsonData;
          print(
            '✅ Respuesta es una lista directa con ${dataList.length} elementos',
          );
        } else if (jsonData is Map<String, dynamic>) {
          // Si el servidor devuelve un objeto con campo 'data'
          if (jsonData.containsKey('data')) {
            final data = jsonData['data'];
            if (data is List) {
              dataList = data;
              print(
                '✅ Respuesta tiene campo data con ${dataList.length} elementos',
              );
            } else {
              print('❌ Campo data no es una lista: ${data.runtimeType}');
              throw Exception('El campo data no contiene una lista válida');
            }
          } else {
            print('❌ Respuesta no tiene campo data');
            throw Exception(
              'Respuesta del servidor no tiene el formato esperado',
            );
          }
        } else {
          print('❌ Tipo de respuesta no reconocido: ${jsonData.runtimeType}');
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
              print(
                '⚠️ Elemento $i no es un Map válido: ${facturaJson.runtimeType}',
              );
            }
          } catch (e) {
            print('⚠️ Error al parsear factura $i: $e');
          }
        }

        print('✅ ${facturas.length} facturas procesadas exitosamente');

        // Ordenar facturas por fecha descendente (más recientes primero)
        facturas.sort((a, b) => b.fechaCreacion.compareTo(a.fechaCreacion));

        return facturas;
      } else {
        final errorMessage =
            'Error al cargar facturas de compras: ${response.statusCode}';
        print('❌ $errorMessage');
        print('📄 Error body: ${response.body}');
        throw Exception(errorMessage);
      }
    } catch (e) {
      print('💥 Error en getFacturasCompras: $e');
      throw Exception('Error de conexión: $e');
    }
  }

  Future<FacturaCompra> getFacturaCompra(String id) async {
    try {
      print('🔍 Obteniendo factura de compra: $id');
      final response = await http.get(
        Uri.parse('$baseUrl/$id'),
        headers: headers,
      );

      print('📡 Factura response status: ${response.statusCode}');
      print('📄 Factura response body: ${response.body}');

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
      print('💥 Error en getFacturaCompra: $e');
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
      print('🔢 Generando número de factura...');
      print('🌐 URL: $baseUrl/numero-factura');

      final response = await http.get(
        Uri.parse('$baseUrl/numero-factura'),
        headers: headers,
      );

      print('📡 Número factura response status: ${response.statusCode}');
      print('📄 Número factura response body: ${response.body}');

      if (response.statusCode == 200) {
        final responseBody = response.body;
        if (responseBody.isEmpty) {
          print('⚠️ Response body vacío para número de factura');
          throw Exception(
            'Respuesta vacía del servidor para número de factura',
          );
        }

        final dynamic jsonData = json.decode(responseBody);
        print('📊 Tipo de respuesta número factura: ${jsonData.runtimeType}');

        String numeroFactura = '';

        if (jsonData is Map<String, dynamic>) {
          // Verificar si hay error en la respuesta
          if (jsonData.containsKey('success') && jsonData['success'] == false) {
            final errorMessage =
                jsonData['message'] ?? 'Error desconocido al generar número';
            print('❌ Error del servidor al generar número: $errorMessage');
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
            print('❌ No se pudo extraer el número de factura de la respuesta');
            print('📋 Claves disponibles: ${jsonData.keys.toList()}');
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

        print('✅ Número de factura generado: $numeroFactura');
        return numeroFactura;
      } else {
        final errorMessage =
            'Error al generar número de factura: ${response.statusCode}';
        print('❌ $errorMessage');
        print('📄 Error body: ${response.body}');
        throw Exception(errorMessage);
      }
    } catch (e) {
      print('💥 Error en generarNumeroFactura: $e');
      throw Exception('Error de conexión: $e');
    }
  }

  Future<List<Ingrediente>> getIngredientesDisponibles() async {
    try {
      print('🔍 Obteniendo ingredientes disponibles...');
      final response = await http.get(
        Uri.parse('$baseUrl/ingredientes'),
        headers: headers,
      );

      print('📡 Ingredientes response status: ${response.statusCode}');
      print('📄 Ingredientes response body: ${response.body}');

      if (response.statusCode == 200) {
        final responseBody = response.body;
        if (responseBody.isEmpty) {
          print('⚠️ Response body vacío para ingredientes');
          return [];
        }

        final dynamic jsonData = json.decode(responseBody);
        print('📊 Tipo de datos de ingredientes: ${jsonData.runtimeType}');

        List<dynamic> dataList;

        // Manejar diferentes tipos de respuesta del servidor
        if (jsonData is List) {
          // Si el servidor devuelve directamente una lista
          dataList = jsonData;
          print(
            '✅ Ingredientes: respuesta es una lista directa con ${dataList.length} elementos',
          );
        } else if (jsonData is Map<String, dynamic>) {
          // Si el servidor devuelve un objeto con campo 'data'
          if (jsonData.containsKey('data')) {
            final data = jsonData['data'];
            if (data is List) {
              dataList = data;
              print(
                '✅ Ingredientes: respuesta tiene campo data con ${dataList.length} elementos',
              );
            } else {
              print(
                '❌ Ingredientes: Campo data no es una lista: ${data.runtimeType}',
              );
              throw Exception(
                'El campo data de ingredientes no contiene una lista válida',
              );
            }
          } else {
            print('❌ Ingredientes: Respuesta no tiene campo data');
            throw Exception(
              'Respuesta de ingredientes no tiene el formato esperado',
            );
          }
        } else {
          print(
            '❌ Ingredientes: Tipo de respuesta no reconocido: ${jsonData.runtimeType}',
          );
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
              print(
                '⚠️ Ingrediente $i no es un Map válido: ${ingredienteJson.runtimeType}',
              );
            }
          } catch (e) {
            print('⚠️ Error al parsear ingrediente $i: $e');
          }
        }

        print('✅ ${ingredientes.length} ingredientes procesados exitosamente');
        return ingredientes;
      } else {
        final errorMessage =
            'Error al cargar ingredientes: ${response.statusCode}';
        print('❌ $errorMessage');
        print('📄 Error body ingredientes: ${response.body}');
        throw Exception(errorMessage);
      }
    } catch (e) {
      print('💥 Error en getIngredientesDisponibles: $e');
      throw Exception('Error de conexión: $e');
    }
  }

  Future<FacturaCompra> crearFacturaCompra(FacturaCompra facturaCompra) async {
    try {
      print(
        '🏁 Iniciando creación de factura de compra con ${facturaCompra.items.length} items',
      );

      // Verificar si hay items
      if (facturaCompra.items.isEmpty) {
        print('⚠️ Advertencia: La factura no tiene items');
      } else {
        print('📋 Items de la factura:');
        for (var i = 0; i < facturaCompra.items.length; i++) {
          final item = facturaCompra.items[i];
          print(
            '📝 Item $i: ${item.ingredienteNombre} - ${item.cantidad} ${item.unidad} x ${item.precioUnitario} = ${item.subtotal}',
          );
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
        print(
          '⚠️ Advertencia: itemsIngredientes está vacío en el JSON pero hay ${facturaCompra.items.length} items en el objeto',
        );
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
              },
            )
            .toList();
      }

      // Verificar que el total está presente en el JSON
      if (facturaJson['total'] == 0 && calculatedTotal > 0) {
        print(
          '⚠️ Advertencia: El total en el JSON es 0 pero el calculado es $calculatedTotal',
        );
        facturaJson['total'] = calculatedTotal;
      }

      print('🔧 Creando factura de compra...');
      print('💰 Total calculado: $calculatedTotal');
      print('📦 Datos a enviar: ${json.encode(facturaJson)}');
      print('🌐 URL: $baseUrl/crear');
      print('📋 Headers: $headers');

      final response = await http.post(
        Uri.parse('$baseUrl/crear'),
        headers: headers,
        body: json.encode(facturaJson),
      );

      print('📡 Crear factura response status: ${response.statusCode}');
      print('📄 Crear factura response body: ${response.body}');

      if (response.statusCode == 201 || response.statusCode == 200) {
        final responseBody = response.body;
        if (responseBody.isEmpty) {
          throw Exception('Respuesta vacía del servidor al crear factura');
        }

        final dynamic jsonData = json.decode(responseBody);
        print('📊 Tipo de respuesta: ${jsonData.runtimeType}');
        print('📄 Respuesta completa: $jsonData');

        if (jsonData is Map<String, dynamic>) {
          // Verificar si la respuesta indica éxito
          if (jsonData.containsKey('success') && jsonData['success'] == false) {
            final errorMessage =
                jsonData['message'] ?? 'Error desconocido al crear factura';
            print('❌ Error del servidor: $errorMessage');
            throw Exception(errorMessage);
          }

          // Intentar obtener los datos de la factura creada
          Map<String, dynamic>? facturaData;

          // El backend devuelve la factura en el campo 'factura'
          if (jsonData.containsKey('factura') && jsonData['factura'] != null) {
            facturaData = jsonData['factura'];
            print('✅ Datos de factura encontrados en campo factura');

            // Validar que la factura tenga los items y el total correcto
            if (facturaData!['itemsIngredientes'] is List &&
                (facturaData['itemsIngredientes'] as List).isEmpty &&
                facturaJson.containsKey('itemsIngredientes') &&
                (facturaJson['itemsIngredientes'] as List).isNotEmpty) {
              print(
                '⚠️ El servidor devolvió una factura sin items pero se enviaron items',
              );
              print(
                '⚠️ Corrigiendo la factura devuelta con los datos enviados',
              );

              // Copiar los items enviados a la respuesta
              facturaData['itemsIngredientes'] =
                  facturaJson['itemsIngredientes'];
              facturaData['total'] = calculatedTotal;
            }

            // Si el total es 0 pero calculamos uno diferente, corregirlo
            if (facturaData['total'] == 0.0 && calculatedTotal > 0) {
              print(
                '⚠️ El servidor devolvió total=0 pero calculamos $calculatedTotal',
              );
              facturaData['total'] = calculatedTotal;
            }
          } else if (jsonData.containsKey('data') && jsonData['data'] != null) {
            facturaData = jsonData['data'];
            print('✅ Datos de factura encontrados en campo data');
          } else if (jsonData.containsKey('success') &&
              jsonData['success'] == true) {
            // Si hay success=true pero no data, puede que los datos estén en el nivel raíz
            facturaData = Map<String, dynamic>.from(jsonData);
            facturaData.remove('success');
            facturaData.remove('message');
            facturaData.remove(
              'numeroFactura',
            ); // El numero se incluye separado
            print('✅ Datos de factura encontrados en nivel raíz');
          } else {
            // Si no hay campo 'data' ni 'success', asumir que toda la respuesta son los datos
            facturaData = jsonData;
            print('✅ Usando respuesta completa como datos de factura');
          }

          if (facturaData == null || facturaData.isEmpty) {
            throw Exception(
              'No se encontraron datos de la factura creada en la respuesta',
            );
          }

          print('✅ Factura creada exitosamente');
          print('📋 Datos de factura finales: $facturaData');

          // Crear objeto FacturaCompra con los items y total calculado explícitamente
          final facturaCreada = FacturaCompra.fromJson(facturaData);

          // Verificación final
          if (facturaCreada.total == 0 && calculatedTotal > 0) {
            print(
              '⚠️ Después de todo el proceso, el total sigue siendo 0. Usando constructor manual.',
            );
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
          print('⚠️ No se pudo parsear el error del servidor: $parseError');
          print('📄 Raw error response: ${response.body}');
        }

        print('❌ $errorMessage');
        throw Exception(errorMessage);
      }
    } catch (e) {
      print('💥 Error en crearFacturaCompra: $e');
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

    print('🔧 Iniciando pruebas de conectividad del backend...');
    print('🌐 Base URL: $baseUrl');

    // Test 1: Probar endpoint de número de factura
    try {
      print('📡 Test 1: Probando generación de número de factura...');
      final numeroResponse = await http.get(
        Uri.parse('$baseUrl/numero-factura'),
        headers: headers,
      );

      result['tests']['numero_factura'] = {
        'status': numeroResponse.statusCode,
        'body': numeroResponse.body,
        'success': numeroResponse.statusCode == 200,
      };

      print('✅ Test 1 completado: ${numeroResponse.statusCode}');
    } catch (e) {
      result['tests']['numero_factura'] = {
        'status': 'ERROR',
        'error': e.toString(),
        'success': false,
      };
      print('❌ Test 1 falló: $e');
    }

    // Test 2: Probar endpoint de listado de facturas
    try {
      print('📡 Test 2: Probando listado de facturas...');
      final listResponse = await http.get(Uri.parse(baseUrl), headers: headers);

      result['tests']['list_facturas'] = {
        'status': listResponse.statusCode,
        'body_length': listResponse.body.length,
        'success': listResponse.statusCode == 200,
      };

      print('✅ Test 2 completado: ${listResponse.statusCode}');
    } catch (e) {
      result['tests']['list_facturas'] = {
        'status': 'ERROR',
        'error': e.toString(),
        'success': false,
      };
      print('❌ Test 2 falló: $e');
    }

    // Test 3: Probar endpoint de creación (con datos de prueba)
    try {
      print('📡 Test 3: Probando endpoint de creación (sin enviar datos)...');
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

      print('✅ Test 3 completado: ${createResponse.statusCode}');
    } catch (e) {
      result['tests']['create_endpoint'] = {
        'status': 'ERROR',
        'error': e.toString(),
        'reachable': false,
      };
      print('❌ Test 3 falló: $e');
    }

    print('🔧 Pruebas de conectividad completadas');
    return result;
  }

  /// Eliminar factura de compra (con reversión automática de stock y dinero)
  Future<Map<String, dynamic>> eliminarFacturaCompra(String id) async {
    try {
      print('🗑️ Eliminando factura de compra: $id');

      final response = await http.delete(
        Uri.parse('$baseUrl/$id'),
        headers: headers,
      );

      print('🗑️ Status eliminación: ${response.statusCode}');
      print('🗑️ Response body: ${response.body}');

      if (response.statusCode == 204 || response.statusCode == 200) {
        // El backend maneja automáticamente:
        // - Reversión de stock de productos/ingredientes
        // - Reversión de dinero del cuadre de caja
        // - Registro en historial de ediciones

        print('✅ Factura eliminada con reversión automática');

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
          print(
            '⚠️ No se pudo parsear la respuesta de eliminación: $parseError',
          );
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
      print('❌ Error eliminando factura de compra: $e');
      throw Exception('Error de conexión: $e');
    }
  }

  /// Anular factura de compra (alternativa a eliminación para auditoría)
  Future<Map<String, dynamic>> anularFacturaCompra(
    String id,
    String motivoAnulacion,
  ) async {
    try {
      print('🚫 Anulando factura de compra: $id');

      final response = await http.patch(
        Uri.parse('$baseUrl/$id/anular'),
        headers: headers,
        body: json.encode({'motivoAnulacion': motivoAnulacion}),
      );

      print('🚫 Status anulación: ${response.statusCode}');
      print('🚫 Response body: ${response.body}');

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

        print('✅ Factura anulada con reversión automática');
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
      print('❌ Error anulando factura: $e');
      throw Exception('Error de conexión: $e');
    }
  }
}
