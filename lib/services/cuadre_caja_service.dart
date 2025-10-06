import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/cuadre_caja.dart';
import '../config/api_config.dart';

class CuadreCajaService {
  static final CuadreCajaService _instance = CuadreCajaService._internal();
  factory CuadreCajaService() => _instance;
  CuadreCajaService._internal();

  String get baseUrl => ApiConfig.instance.baseUrl;
  final storage = FlutterSecureStorage();

  // Headers con autenticación
  Future<Map<String, String>> _getHeaders() async {
    final token = await storage.read(key: 'jwt_token');
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // Obtener todos los cuadres de caja
  Future<List<CuadreCaja>> getAllCuadres() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/api/cuadres-caja'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        List<dynamic> jsonList = responseData['data'] ?? [];
        final cuadres = jsonList
            .map((json) => CuadreCaja.fromJson(json))
            .toList();

        // Ordenar cuadres por fecha de inicio descendente (más recientes primero)
        cuadres.sort(
          (a, b) =>
              b.fechaInicio?.compareTo(a.fechaInicio ?? DateTime(1900)) ?? 0,
        );

        return cuadres;
      } else {
        throw Exception('Error al obtener cuadres: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }

  // Obtener cuadre por ID
  Future<CuadreCaja?> getCuadreById(String id) async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/api/cuadres-caja/$id'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        return CuadreCaja.fromJson(responseData['data']);
      } else if (response.statusCode == 404) {
        return null;
      } else {
        throw Exception('Error al obtener cuadre: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }

  // Obtener cuadres por responsable
  Future<List<CuadreCaja>> getCuadresByResponsable(String responsable) async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/api/cuadres-caja/responsable/$responsable'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        List<dynamic> jsonList = responseData['data'] ?? [];
        final cuadres = jsonList
            .map((json) => CuadreCaja.fromJson(json))
            .toList();

        // Ordenar cuadres por fecha de inicio descendente (más recientes primero)
        cuadres.sort(
          (a, b) =>
              b.fechaInicio?.compareTo(a.fechaInicio ?? DateTime(1900)) ?? 0,
        );

        return cuadres;
      } else {
        throw Exception(
          'Error al obtener cuadres por responsable: ${response.statusCode}',
        );
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }

  // Obtener cuadres por estado
  Future<List<CuadreCaja>> getCuadresByEstado(String estado) async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/api/cuadres-caja/estado/$estado'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        List<dynamic> jsonList = responseData['data'] ?? [];
        final cuadres = jsonList
            .map((json) => CuadreCaja.fromJson(json))
            .toList();

        // Ordenar cuadres por fecha de inicio descendente (más recientes primero)
        cuadres.sort(
          (a, b) =>
              b.fechaInicio?.compareTo(a.fechaInicio ?? DateTime(1900)) ?? 0,
        );

        return cuadres;
      } else {
        throw Exception(
          'Error al obtener cuadres por estado: ${response.statusCode}',
        );
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }

  // Obtener cuadres de hoy
  Future<List<CuadreCaja>> getCuadresHoy() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/api/cuadres-caja/hoy'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        List<dynamic> jsonList = responseData['data'] ?? [];
        final cuadres = jsonList
            .map((json) => CuadreCaja.fromJson(json))
            .toList();

        // Ordenar cuadres por fecha de inicio descendente (más recientes primero)
        cuadres.sort(
          (a, b) =>
              b.fechaInicio?.compareTo(a.fechaInicio ?? DateTime(1900)) ?? 0,
        );

        return cuadres;
      } else {
        throw Exception(
          'Error al obtener cuadres de hoy: ${response.statusCode}',
        );
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }

  // Obtener cajas abiertas
  Future<List<CuadreCaja>> getCajasAbiertas() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/api/cuadres-caja/abiertas'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        List<dynamic> jsonList = responseData['data'] ?? [];
        final cuadres = jsonList
            .map((json) => CuadreCaja.fromJson(json))
            .toList();

        // Ordenar cuadres por fecha de inicio descendente (más recientes primero)
        cuadres.sort(
          (a, b) =>
              b.fechaInicio?.compareTo(a.fechaInicio ?? DateTime(1900)) ?? 0,
        );

        return cuadres;
      } else {
        throw Exception(
          'Error al obtener cajas abiertas: ${response.statusCode}',
        );
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }

  // Obtener la caja activa actual (primera caja abierta)
  Future<CuadreCaja?> getCajaActiva() async {
    try {
      print('🔍 Buscando caja activa...');
      final cajasAbiertas = await getCajasAbiertas();

      if (cajasAbiertas.isEmpty) {
        print('⚠️ No se encontró ninguna caja abierta');
        return null;
      }

      final cajaActiva = cajasAbiertas.first;
      print(
        '✅ Caja activa encontrada: ${cajaActiva.id} - ${cajaActiva.nombre}',
      );
      return cajaActiva;
    } catch (e) {
      print('❌ Error al obtener caja activa: $e');
      return null;
    }
  }

  // Validar si hay una caja abierta (método de conveniencia)
  Future<bool> hayCajaAbierta() async {
    try {
      final cajaActiva = await getCajaActiva();
      return cajaActiva != null;
    } catch (e) {
      print('❌ Error validando caja abierta: $e');
      return false;
    }
  }

  // Obtener efectivo esperado con logging detallado
  Future<Map<String, dynamic>> getEfectivoEsperado() async {
    try {
      print('🔍 Iniciando cálculo de efectivo esperado...');
      final headers = await _getHeaders();

      final response = await http.get(
        Uri.parse('$baseUrl/api/cuadres-caja/efectivo-esperado'),
        headers: headers,
      );

      print('📡 Respuesta del servidor - Status: ${response.statusCode}');
      print('📄 Headers de respuesta: ${response.headers}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        print('✅ Datos recibidos: $responseData');

        final efectivoEsperado = (responseData['data']['efectivoEsperado'] ?? 0)
            .toDouble();
        final transferenciasEsperadas =
            (responseData['data']['transferenciasEsperadas'] ??
                    responseData['data']['transferenciaEsperada'] ??
                    0)
                .toDouble();

        print(
          '💰 Efectivo esperado calculado: \$${efectivoEsperado.toStringAsFixed(2)}',
        );
        print(
          '🏦 Transferencias esperadas: \$${transferenciasEsperadas.toStringAsFixed(2)}',
        );

        return responseData['data'];
      } else {
        print('❌ Error del servidor: ${response.statusCode}');
        print('📝 Body de error: ${response.body}');

        // Fallback: intentar calcular manualmente desde pedidos
        return await _calcularEfectivoManual();
      }
    } catch (e) {
      print('💥 Error de conexión: $e');
      // Fallback: intentar calcular manualmente desde pedidos
      return await _calcularEfectivoManual();
    }
  }

  // Método fallback para calcular efectivo manualmente
  Future<Map<String, dynamic>> _calcularEfectivoManual() async {
    try {
      print('🔧 Iniciando cálculo manual del efectivo esperado...');

      // Usar el nuevo método que obtiene datos por cuadre activo
      Map<String, dynamic>? ventasData;

      try {
        ventasData = await getVentasPorCuadreActivo();
        print('✅ Datos de ventas del cuadre activo obtenidos exitosamente');
      } catch (e) {
        print('⚠️ Error al obtener ventas del cuadre activo: $e');

        // Fallback a los métodos antiguos
        try {
          ventasData = await getVentasPorCuadreActivo();
          print('✅ Datos de ventas por fecha obtenidos como fallback');
        } catch (e2) {
          print('⚠️ Error al obtener ventas por fecha: $e2');

          try {
            ventasData = await getDetallesVentas();
            print('✅ Datos de ventas obtenidos exitosamente');
          } catch (e3) {
            print('⚠️ Error al obtener detalles de ventas: $e3');
          }
        }
      }

      if (ventasData == null) {
        try {
          ventasData = await getTodosPedidosHoy();
          print('✅ Datos de pedidos obtenidos exitosamente');
        } catch (e) {
          print('⚠️ Error al obtener pedidos: $e');
        }
      }

      double efectivoEsperado = 0.0;
      double transferenciasEsperadas = 0.0;

      if (ventasData != null) {
        print('📊 Procesando datos de ventas...');
        print('🔍 Estructura de datos recibida: ${ventasData.keys.toList()}');

        // Procesar los datos según la estructura que venga del backend
        if (ventasData.containsKey('efectivo')) {
          efectivoEsperado = (ventasData['efectivo'] ?? 0).toDouble();
          print(
            '💰 Efectivo desde campo directo: \$${efectivoEsperado.toStringAsFixed(2)}',
          );
        }

        if (ventasData.containsKey('transferencias')) {
          transferenciasEsperadas = (ventasData['transferencias'] ?? 0)
              .toDouble();
          print(
            '🏦 Transferencias desde campo directo: \$${transferenciasEsperadas.toStringAsFixed(2)}',
          );
        } else if (ventasData.containsKey('transferencia')) {
          transferenciasEsperadas = (ventasData['transferencia'] ?? 0)
              .toDouble();
          print(
            '🏦 Transferencias desde campo alternativo: \$${transferenciasEsperadas.toStringAsFixed(2)}',
          );
        }

        // Si vienen datos por tipo de pago, procesarlos
        if (ventasData.containsKey('ventasPorTipo')) {
          final ventasPorTipo =
              ventasData['ventasPorTipo'] as Map<String, dynamic>? ?? {};
          print('💳 Procesando ventas por tipo de pago: $ventasPorTipo');

          ventasPorTipo.forEach((tipoPago, monto) {
            double valor = (monto ?? 0).toDouble();
            String tipo = tipoPago.toLowerCase();

            if (tipo.contains('efectivo') || tipo == 'cash') {
              efectivoEsperado += valor;
              print('💵 Agregado a efectivo: \$${valor.toStringAsFixed(2)}');
            } else if (tipo.contains('transfer') ||
                tipo.contains('debito') ||
                tipo.contains('tarjeta')) {
              transferenciasEsperadas += valor;
              print(
                '💳 Agregado a transferencias: \$${valor.toStringAsFixed(2)}',
              );
            }
          });
        }

        // Si no vienen datos específicos, sumar pedidos manualmente
        if ((efectivoEsperado == 0 && transferenciasEsperadas == 0) &&
            ventasData.containsKey('pedidos')) {
          print('📋 Calculando desde lista de pedidos...');
          List<dynamic> pedidos = ventasData['pedidos'] ?? [];
          print('📊 Total de pedidos a procesar: ${pedidos.length}');

          for (var pedido in pedidos) {
            if (pedido['estado'] == 'pagado') {
              double total = (pedido['total'] ?? 0).toDouble();
              String tipoPago =
                  (pedido['tipoPago'] ?? pedido['tipo_pago'] ?? 'efectivo')
                      .toString()
                      .toLowerCase();

              print(
                '🧾 Procesando pedido - Total: \$${total.toStringAsFixed(2)}, Tipo: $tipoPago',
              );

              if (tipoPago.contains('efectivo') || tipoPago == 'cash') {
                efectivoEsperado += total;
                print('💵 Sumado a efectivo: \$${total.toStringAsFixed(2)}');
              } else if (tipoPago.contains('transfer') ||
                  tipoPago.contains('debito') ||
                  tipoPago.contains('tarjeta')) {
                transferenciasEsperadas += total;
                print(
                  '💳 Sumado a transferencias: \$${total.toStringAsFixed(2)}',
                );
              } else {
                // Por defecto, considerar como efectivo si no se especifica
                efectivoEsperado += total;
                print(
                  '💵 Tipo desconocido, sumado a efectivo por defecto: \$${total.toStringAsFixed(2)}',
                );
              }
            }
          }
        }
      }

      print('🔧 Cálculo manual completado:');
      print('💰 Efectivo total: \$${efectivoEsperado.toStringAsFixed(2)}');
      print(
        '🏦 Transferencias total: \$${transferenciasEsperadas.toStringAsFixed(2)}',
      );
      print(
        '📊 Gran total: \$${(efectivoEsperado + transferenciasEsperadas).toStringAsFixed(2)}',
      );

      return {
        'efectivoEsperado': efectivoEsperado,
        'transferenciasEsperadas': transferenciasEsperadas,
        'transferenciaEsperada': transferenciasEsperadas, // Compatibilidad
        'totalVentas': efectivoEsperado + transferenciasEsperadas,
        'calculoManual': true,
        'timestamp': DateTime.now().toIso8601String(),
        'detalleCalculo': {
          'efectivo': efectivoEsperado,
          'transferencias': transferenciasEsperadas,
        },
      };
    } catch (e) {
      print('💥 Error en cálculo manual: $e');
      // Devolver valores por defecto en caso de error total
      return {
        'efectivoEsperado': 0.0,
        'transferenciasEsperadas': 0.0,
        'transferenciaEsperada': 0.0,
        'totalVentas': 0.0,
        'error': 'No se pudo calcular el efectivo esperado: $e',
        'timestamp': DateTime.now().toIso8601String(),
      };
    }
  }

  // Crear cuadre de caja
  Future<CuadreCaja> createCuadre({
    required String nombre,
    required String responsable,
    required double fondoInicial,
    required double efectivoDeclarado,
    required double efectivoEsperado,
    required double tolerancia,
    String? observaciones,
  }) async {
    try {
      final headers = await _getHeaders();
      final body = {
        'nombre': nombre,
        'responsable': responsable,
        'fondoInicial': fondoInicial,
        'efectivoDeclarado': efectivoDeclarado,
        'efectivoEsperado': efectivoEsperado,
        'tolerancia': tolerancia,
        'observaciones': observaciones ?? '',
      };

      final response = await http.post(
        Uri.parse('$baseUrl/api/cuadres-caja'),
        headers: headers,
        body: json.encode(body),
      );

      if (response.statusCode == 201) {
        final responseData = json.decode(response.body);
        return CuadreCaja.fromJson(responseData['data']);
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? 'Error al crear cuadre');
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }

  // Actualizar cuadre de caja
  Future<CuadreCaja> updateCuadre(
    String id, {
    String? nombre,
    String? responsable,
    double? fondoInicial,
    double? efectivoDeclarado,
    double? efectivoEsperado,
    double? tolerancia,
    String? observaciones,
    bool? cerrarCaja, // Cambio de cerrada a cerrarCaja
    String? estado,
  }) async {
    try {
      final headers = await _getHeaders();
      final body = {
        if (nombre != null) 'nombre': nombre,
        if (responsable != null) 'responsable': responsable,
        if (fondoInicial != null) 'fondoInicial': fondoInicial,
        if (efectivoDeclarado != null) 'efectivoDeclarado': efectivoDeclarado,
        if (efectivoEsperado != null) 'efectivoEsperado': efectivoEsperado,
        if (tolerancia != null) 'tolerancia': tolerancia,
        if (observaciones != null) 'observaciones': observaciones,
        if (cerrarCaja != null)
          'cerrarCaja': cerrarCaja, // Campo correcto para el backend
        if (estado != null) 'estado': estado,
      };

      final response = await http.put(
        Uri.parse('$baseUrl/api/cuadres-caja/$id'),
        headers: headers,
        body: json.encode(body),
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        return CuadreCaja.fromJson(responseData['data']);
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? 'Error al actualizar cuadre');
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }

  // Aprobar cuadre
  Future<CuadreCaja> aprobarCuadre(String id, String aprobador) async {
    try {
      final headers = await _getHeaders();
      final body = {'aprobador': aprobador};

      final response = await http.put(
        Uri.parse('$baseUrl/api/cuadres-caja/$id/aprobar'),
        headers: headers,
        body: json.encode(body),
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        return CuadreCaja.fromJson(responseData['data']);
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? 'Error al aprobar cuadre');
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }

  // Rechazar cuadre
  Future<CuadreCaja> rechazarCuadre(
    String id,
    String aprobador, {
    String? observacion,
  }) async {
    try {
      final headers = await _getHeaders();
      final body = {
        'aprobador': aprobador,
        if (observacion != null) 'observacion': observacion,
      };

      final response = await http.put(
        Uri.parse('$baseUrl/api/cuadres-caja/$id/rechazar'),
        headers: headers,
        body: json.encode(body),
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        return CuadreCaja.fromJson(responseData['data']);
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? 'Error al rechazar cuadre');
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }

  // Eliminar cuadre
  Future<bool> deleteCuadre(String id) async {
    try {
      final headers = await _getHeaders();
      final response = await http.delete(
        Uri.parse('$baseUrl/api/cuadres-caja/$id'),
        headers: headers,
      );

      return response.statusCode == 200;
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }

  // Debug de pedidos - para verificar qué pedidos están registrados
  Future<Map<String, dynamic>> debugPedidos() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/api/cuadres-caja/debug-pedidos'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        return responseData['data'];
      } else {
        throw Exception(
          'Error al obtener debug de pedidos: ${response.statusCode}',
        );
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }

  Future<Map<String, dynamic>> getDetallesVentas() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/api/cuadres-caja/detalles-ventas'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        return responseData['data'];
      } else {
        throw Exception(
          'Error al obtener detalles de ventas: ${response.statusCode}',
        );
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }

  Future<Map<String, dynamic>> getTodosPedidosHoy() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/api/cuadres-caja/todos-pedidos-hoy'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        return responseData['data'];
      } else {
        throw Exception(
          'Error al obtener todos los pedidos: ${response.statusCode}',
        );
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }

  // Obtener ventas por cuadre de caja activo en lugar de por fecha
  Future<Map<String, dynamic>> getVentasPorCuadreActivo() async {
    try {
      print('🔍 Obteniendo ventas del cuadre de caja activo...');
      final headers = await _getHeaders();

      // Obtener la caja activa
      final cajaActiva = await getCajaActiva();
      if (cajaActiva == null) {
        print('⚠️ No hay caja activa para obtener ventas');
        return {
          'total': 0.0,
          'efectivo': 0.0,
          'transferencias': 0.0,
          'tarjeta': 0.0,
          'otros': 0.0,
        };
      }

      print('💰 Obteniendo pedidos pagados del cuadre: ${cajaActiva.id}');
      final response = await http.get(
        Uri.parse('$baseUrl/api/pedidos/cuadre/${cajaActiva.id}/pagados'),
        headers: headers,
      );

      print('📡 Respuesta pedidos de cuadre - Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        print('✅ Pedidos del cuadre recibidos: $responseData');

        // Procesar pedidos para calcular totales por tipo de pago
        final List<dynamic> pedidos = responseData['data'] ?? [];
        double totalEfectivo = 0.0;
        double totalTransferencias = 0.0;
        double totalTarjeta = 0.0;
        double totalOtros = 0.0;

        for (var pedidoJson in pedidos) {
          final double totalPedido =
              (pedidoJson['totalPagado'] ?? pedidoJson['total'] ?? 0)
                  .toDouble();
          final String formaPago = (pedidoJson['formaPago'] ?? 'otros')
              .toString()
              .toLowerCase();

          switch (formaPago) {
            case 'efectivo':
              totalEfectivo += totalPedido;
              break;
            case 'transferencia':
              totalTransferencias += totalPedido;
              break;
            case 'tarjeta':
              totalTarjeta += totalPedido;
              break;
            default:
              totalOtros += totalPedido;
          }
        }

        final double total =
            totalEfectivo + totalTransferencias + totalTarjeta + totalOtros;

        print('📊 Resumen de ventas del cuadre ${cajaActiva.id}:');
        print('  - Efectivo: \$${totalEfectivo.toStringAsFixed(2)}');
        print(
          '  - Transferencias: \$${totalTransferencias.toStringAsFixed(2)}',
        );
        print('  - Tarjetas: \$${totalTarjeta.toStringAsFixed(2)}');
        print('  - Otros: \$${totalOtros.toStringAsFixed(2)}');
        print('  - Total: \$${total.toStringAsFixed(2)}');

        return {
          'total': total,
          'efectivo': totalEfectivo,
          'transferencias': totalTransferencias,
          'tarjeta': totalTarjeta,
          'otros': totalOtros,
        };
      } else {
        print('❌ Error al obtener pedidos del cuadre: ${response.statusCode}');
        print('📝 Body de error: ${response.body}');

        return {
          'total': 0.0,
          'efectivo': 0.0,
          'transferencias': 0.0,
          'tarjeta': 0.0,
          'otros': 0.0,
        };
      }
    } catch (e) {
      print('💥 Error en getVentasPorTipoPago: $e');
      throw Exception('Error de conexión: $e');
    }
  }

  // Obtener resumen completo de ventas del día
  Future<Map<String, dynamic>> getResumenVentasHoy() async {
    try {
      print('🔍 Obteniendo resumen completo de ventas del día...');
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/api/cuadres-caja/resumen-ventas-hoy'),
        headers: headers,
      );

      print('📡 Respuesta resumen ventas - Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        print('✅ Resumen de ventas recibido: $responseData');
        return responseData['data'];
      } else {
        print('❌ Error al obtener resumen de ventas: ${response.statusCode}');
        print('📝 Body de error: ${response.body}');
        throw Exception(
          'Error al obtener resumen de ventas: ${response.statusCode}',
        );
      }
    } catch (e) {
      print('💥 Error en getResumenVentasHoy: $e');
      throw Exception('Error de conexión: $e');
    }
  }

  // Método para compatibilidad con código legacy - alias de getVentasPorCuadreActivo
  Future<Map<String, dynamic>> getVentasPorTipoPago() async {
    print(
      '🔄 getVentasPorTipoPago() - redirigiendo a getVentasPorCuadreActivo()',
    );
    return await getVentasPorCuadreActivo();
  }

  // Obtener información completa del cuadre actual incluyendo contadores
  Future<Map<String, dynamic>> getCuadreCompleto() async {
    try {
      print('🔍 Obteniendo información completa del cuadre...');
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/api/cuadres-caja/cuadre-completo'),
        headers: headers,
      );

      print('📡 Respuesta cuadre completo - Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        print('✅ Información completa del cuadre recibida: $responseData');
        return responseData['data'];
      } else {
        print('❌ Error al obtener cuadre completo: ${response.statusCode}');
        print('📝 Body de error: ${response.body}');
        throw Exception(
          'Error al obtener cuadre completo: ${response.statusCode}',
        );
      }
    } catch (e) {
      print('💥 Error en getCuadreCompleto: $e');
      throw Exception('Error de conexión: $e');
    }
  }
}
