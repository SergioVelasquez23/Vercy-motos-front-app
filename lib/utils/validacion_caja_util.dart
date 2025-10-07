import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/material.dart';
import '../config/api_config.dart';
import '../dialogs/dialogo_confirmacion.dart';

/// Utilidad para validar efectivo disponible en caja
///
/// Esta clase proporciona métodos para validar si hay suficiente efectivo
/// disponible en caja antes de realizar operaciones que afectan al efectivo.
class ValidacionCajaUtil {
  static final ApiConfig _apiConfig = ApiConfig.instance;

  /// Valida si hay suficiente efectivo disponible en caja para un monto determinado
  ///
  /// Solo muestra una advertencia si no hay fondos suficientes, pero siempre
  /// retorna true para permitir que la operación continúe.
  /// Esta función no bloquea operaciones, solo advierte sobre fondos insuficientes.
  static Future<bool> validarEfectivoDisponible(double monto) async {
    try {
      final detalles = await obtenerDetallesEfectivo();

      if (detalles.totalEfectivoEnCaja < monto) {
        print('⚠️ ADVERTENCIA: Efectivo insuficiente en caja');
        print(
          '💰 Disponible: \$${detalles.totalEfectivoEnCaja.toStringAsFixed(2)}',
        );
        print('💰 Requerido: \$${monto.toStringAsFixed(2)}');
        print(
          'ℹ️ La operación puede continuar, pero la caja quedará en negativo.',
        );
      } else {
        print('✅ Efectivo suficiente en caja');
      }

      // Siempre retorna true para permitir que la operación continúe
      return true;
    } catch (e) {
      print('❌ Error al validar efectivo disponible: $e');
      // Aún en caso de error, permitir continuar
      return true;
    }
  }

  /// Obtiene los detalles de efectivo en caja
  static Future<DetallesEfectivo> obtenerDetallesEfectivo() async {
    final headers = _apiConfig.getSecureHeaders();
    final baseUrl = '${_apiConfig.baseUrl}/api/cuadres-caja';

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/detalles-ventas'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);

        // Extraer los datos del response, que puede venir en formato wrapper o directo
        Map<String, dynamic> data;
        if (jsonData is Map<String, dynamic> && jsonData.containsKey('data')) {
          data = jsonData['data'];
        } else {
          data = jsonData;
        }

        return DetallesEfectivo.fromJson(data);
      } else {
        throw Exception(
          'Error al obtener detalles de caja: ${response.statusCode}',
        );
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }

  /// Muestra diálogo de confirmación para operaciones que afectan el efectivo
  ///
  /// Si se proporciona [context], muestra un diálogo real de Flutter.
  /// Si no se proporciona [context], solo muestra información en la consola.
  static Future<bool> confirmarOperacionEfectivo({
    required double monto,
    required String tipoOperacion,
    required String detalleOperacion,
    BuildContext? context,
  }) async {
    // Obtener el efectivo actual
    final detalles = await obtenerDetallesEfectivo();
    final efectivoActual = detalles.totalEfectivoEnCaja;
    final efectivoRestante = efectivoActual - monto;

    // Si hay un BuildContext disponible, mostrar un diálogo real
    if (context != null) {
      return DialogoConfirmacion.confirmarOperacionEfectivo(
        context,
        tipo: tipoOperacion,
        detalle: detalleOperacion,
        monto: monto,
        efectivoDisponible: efectivoActual,
      );
    }

    // Si no hay contexto, mostrar información en consola
    print('⚠️ CONFIRMACIÓN DE OPERACIÓN');
    print('📌 Tipo: $tipoOperacion');
    print('📝 Detalle: $detalleOperacion');
    print('💰 Efectivo actual: \$${efectivoActual.toStringAsFixed(2)}');
    print('💰 Monto a utilizar: \$${monto.toStringAsFixed(2)}');
    print('💰 Efectivo restante: \$${efectivoRestante.toStringAsFixed(2)}');

    // Por defecto retornamos true en modo consola
    return true;
  }
}

/// Clase para representar los detalles de efectivo en caja
class DetallesEfectivo {
  final double fondoInicial;
  final double totalVentas;
  final double ventasEfectivo;
  final double ventasTransferencias;
  final double ventasTarjetas;
  final int totalPedidos;
  final int cantidadEfectivo;
  final int cantidadTransferencias;
  final int cantidadTarjetas;
  final double totalGastos;
  final double gastosDesdeCaja;
  final double gastosNoDesdeCaja;
  final double efectivoEsperadoPorVentas;
  final double totalEfectivoEnCaja;

  DetallesEfectivo({
    required this.fondoInicial,
    required this.totalVentas,
    required this.ventasEfectivo,
    required this.ventasTransferencias,
    required this.ventasTarjetas,
    required this.totalPedidos,
    required this.cantidadEfectivo,
    required this.cantidadTransferencias,
    required this.cantidadTarjetas,
    required this.totalGastos,
    required this.gastosDesdeCaja,
    required this.gastosNoDesdeCaja,
    required this.efectivoEsperadoPorVentas,
    required this.totalEfectivoEnCaja,
  });

  /// Crea una instancia de DetallesEfectivo desde un mapa JSON
  factory DetallesEfectivo.fromJson(Map<String, dynamic> json) {
    return DetallesEfectivo(
      fondoInicial: _parseDouble(json['fondoInicial']),
      totalVentas: _parseDouble(json['totalVentas']),
      ventasEfectivo: _parseDouble(json['ventasEfectivo']),
      ventasTransferencias: _parseDouble(json['ventasTransferencias']),
      ventasTarjetas: _parseDouble(json['ventasTarjetas']),
      totalPedidos: json['totalPedidos'] ?? 0,
      cantidadEfectivo: json['cantidadEfectivo'] ?? 0,
      cantidadTransferencias: json['cantidadTransferencias'] ?? 0,
      cantidadTarjetas: json['cantidadTarjetas'] ?? 0,
      totalGastos: _parseDouble(json['totalGastos']),
      gastosDesdeCaja: _parseDouble(json['gastosDesdeCaja']),
      gastosNoDesdeCaja: _parseDouble(json['gastosNoDesdeCaja']),
      efectivoEsperadoPorVentas: _parseDouble(
        json['efectivoEsperadoPorVentas'],
      ),
      totalEfectivoEnCaja: _parseDouble(json['totalEfectivoEnCaja']),
    );
  }

  /// Convierte valores a double de forma segura
  static double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is int) return value.toDouble();
    if (value is double) return value;
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }
}
