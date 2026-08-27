import 'dart:io';
import 'dart:typed_data';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';
import 'package:universal_html/html.dart' as html;
import '../models/denominacion_efectivo.dart';
import '../utils/format_utils.dart';

class ExcelExportService {
  /// Exporta el contador de efectivo a un archivo Excel
  static Future<String?> exportarContadorEfectivo({
    required List<DenominacionEfectivo> denominaciones,
    String? nombreUsuario,
    String? observaciones,
  }) async {
    try {
      // Crear nuevo Excel
      var excel = Excel.createExcel();
      Sheet sheetObject = excel['Contador de Efectivo'];
      excel.delete('Sheet1'); // Eliminar hoja por defecto

      // Configurar estilos
      CellStyle headerStyle = CellStyle(
        fontFamily: getFontFamily(FontFamily.Calibri),
        fontSize: 12,
        bold: true,
        backgroundColorHex: ExcelColor.blue,
        fontColorHex: ExcelColor.white,
        horizontalAlign: HorizontalAlign.Center,
      );

      CellStyle titleStyle = CellStyle(
        fontFamily: getFontFamily(FontFamily.Calibri),
        fontSize: 16,
        bold: true,
        horizontalAlign: HorizontalAlign.Center,
      );

      CellStyle totalStyle = CellStyle(
        fontFamily: getFontFamily(FontFamily.Calibri),
        fontSize: 12,
        bold: true,
        backgroundColorHex: ExcelColor.green,
        fontColorHex: ExcelColor.white,
      );

      CellStyle subtotalStyle = CellStyle(
        fontFamily: getFontFamily(FontFamily.Calibri),
        fontSize: 11,
        bold: true,
      );

      CellStyle dataStyle = CellStyle(
        fontFamily: getFontFamily(FontFamily.Calibri),
        fontSize: 11,
      );

      // Configurar anchos de columna
      sheetObject.setColumnWidth(0, 20); // Tipo
      sheetObject.setColumnWidth(1, 25); // Denominación
      sheetObject.setColumnWidth(2, 15); // Cantidad
      sheetObject.setColumnWidth(3, 20); // Subtotal

      int currentRow = 0;

      // TÍTULO PRINCIPAL
      sheetObject.merge(
        CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: currentRow),
        CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: currentRow),
      );
      var titleCell = sheetObject.cell(
        CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: currentRow),
      );
      titleCell.value = TextCellValue('CONTADOR DE EFECTIVO');
      titleCell.cellStyle = titleStyle;
      currentRow += 2;

      // INFORMACIÓN GENERAL
      var infoCell1 = sheetObject.cell(
        CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: currentRow),
      );
      infoCell1.value = TextCellValue(
        'Fecha: ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}',
      );
      infoCell1.cellStyle = dataStyle;

      var infoCell2 = sheetObject.cell(
        CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: currentRow),
      );
      infoCell2.value = TextCellValue(
        'Hora: ${DateTime.now().hour.toString().padLeft(2, '0')}:${DateTime.now().minute.toString().padLeft(2, '0')}',
      );
      infoCell2.cellStyle = dataStyle;
      currentRow++;

      if (nombreUsuario != null && nombreUsuario.isNotEmpty) {
        var userCell = sheetObject.cell(
          CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: currentRow),
        );
        userCell.value = TextCellValue('Usuario: $nombreUsuario');
        userCell.cellStyle = dataStyle;
        currentRow++;
      }

      if (observaciones != null && observaciones.isNotEmpty) {
        var obsCell = sheetObject.cell(
          CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: currentRow),
        );
        obsCell.value = TextCellValue('Observaciones: $observaciones');
        obsCell.cellStyle = dataStyle;
        currentRow++;
      }

      currentRow += 2;

      // ENCABEZADOS
      var headers = ['Tipo', 'Denominación', 'Cantidad', 'Subtotal'];
      for (int i = 0; i < headers.length; i++) {
        var headerCell = sheetObject.cell(
          CellIndex.indexByColumnRow(columnIndex: i, rowIndex: currentRow),
        );
        headerCell.value = TextCellValue(headers[i]);
        headerCell.cellStyle = headerStyle;
      }
      currentRow++;

      // SEPARAR BILLETES Y MONEDAS
      var billetes = denominaciones.where((d) => d.tipo == 'billete').toList();
      var monedas = denominaciones.where((d) => d.tipo == 'moneda').toList();

      double totalBilletes = 0;
      double totalMonedas = 0;

      // BILLETES
      if (billetes.isNotEmpty) {
        // Subtítulo Billetes
        sheetObject.merge(
          CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: currentRow),
          CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: currentRow),
        );
        var billetesTitle = sheetObject.cell(
          CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: currentRow),
        );
        billetesTitle.value = TextCellValue('BILLETES');
        billetesTitle.cellStyle = subtotalStyle;
        currentRow++;

        for (var billete in billetes) {
          if (billete.cantidad > 0) {
            // Tipo
            var tipoCell = sheetObject.cell(
              CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: currentRow),
            );
            tipoCell.value = TextCellValue(billete.tipo.toUpperCase());
            tipoCell.cellStyle = dataStyle;

            // Denominación
            var denomCell = sheetObject.cell(
              CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: currentRow),
            );
            denomCell.value = TextCellValue(billete.valorFormateado);
            denomCell.cellStyle = dataStyle;

            // Cantidad
            var cantCell = sheetObject.cell(
              CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: currentRow),
            );
            cantCell.value = IntCellValue(billete.cantidad);
            cantCell.cellStyle = dataStyle;

            // Subtotal
            var subtotalCell = sheetObject.cell(
              CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: currentRow),
            );
            subtotalCell.value = TextCellValue(formatCurrency(billete.total));
            subtotalCell.cellStyle = dataStyle;

            totalBilletes += billete.total;
            currentRow++;
          }
        }

        // Total billetes
        var totalBilletesCell1 = sheetObject.cell(
          CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: currentRow),
        );
        totalBilletesCell1.value = TextCellValue('TOTAL BILLETES:');
        totalBilletesCell1.cellStyle = subtotalStyle;

        var totalBilletesCell2 = sheetObject.cell(
          CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: currentRow),
        );
        totalBilletesCell2.value = TextCellValue(formatCurrency(totalBilletes));
        totalBilletesCell2.cellStyle = subtotalStyle;
        currentRow += 2;
      }

      // MONEDAS
      if (monedas.isNotEmpty) {
        // Subtítulo Monedas
        sheetObject.merge(
          CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: currentRow),
          CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: currentRow),
        );
        var monedasTitle = sheetObject.cell(
          CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: currentRow),
        );
        monedasTitle.value = TextCellValue('MONEDAS');
        monedasTitle.cellStyle = subtotalStyle;
        currentRow++;

        for (var moneda in monedas) {
          if (moneda.cantidad > 0) {
            // Tipo
            var tipoCell = sheetObject.cell(
              CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: currentRow),
            );
            tipoCell.value = TextCellValue(moneda.tipo.toUpperCase());
            tipoCell.cellStyle = dataStyle;

            // Denominación
            var denomCell = sheetObject.cell(
              CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: currentRow),
            );
            denomCell.value = TextCellValue(moneda.valorFormateado);
            denomCell.cellStyle = dataStyle;

            // Cantidad
            var cantCell = sheetObject.cell(
              CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: currentRow),
            );
            cantCell.value = IntCellValue(moneda.cantidad);
            cantCell.cellStyle = dataStyle;

            // Subtotal
            var subtotalCell = sheetObject.cell(
              CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: currentRow),
            );
            subtotalCell.value = TextCellValue(formatCurrency(moneda.total));
            subtotalCell.cellStyle = dataStyle;

            totalMonedas += moneda.total;
            currentRow++;
          }
        }

        // Total monedas
        var totalMonedasCell1 = sheetObject.cell(
          CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: currentRow),
        );
        totalMonedasCell1.value = TextCellValue('TOTAL MONEDAS:');
        totalMonedasCell1.cellStyle = subtotalStyle;

        var totalMonedasCell2 = sheetObject.cell(
          CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: currentRow),
        );
        totalMonedasCell2.value = TextCellValue(formatCurrency(totalMonedas));
        totalMonedasCell2.cellStyle = subtotalStyle;
        currentRow += 2;
      }

      // TOTAL GENERAL
      sheetObject.merge(
        CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: currentRow),
        CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: currentRow),
      );
      var totalGeneralCell1 = sheetObject.cell(
        CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: currentRow),
      );
      totalGeneralCell1.value = TextCellValue('TOTAL GENERAL:');
      totalGeneralCell1.cellStyle = totalStyle;

      var totalGeneralCell2 = sheetObject.cell(
        CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: currentRow),
      );
      totalGeneralCell2.value = TextCellValue(
        formatCurrency(totalBilletes + totalMonedas),
      );
      totalGeneralCell2.cellStyle = totalStyle;

      // Generar el archivo
      List<int>? fileBytes = excel.save();
      if (fileBytes == null) {
        throw Exception('Error al generar el archivo Excel');
      }

      // Crear nombre del archivo
      String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      String fileName = 'contador_efectivo_$timestamp.xlsx';

      // Guardar archivo
      String? filePath = await _saveExcelFile(fileBytes, fileName);

      return filePath;
    } catch (e) {
        
      return null;
    }
  }

  /// Guarda el archivo Excel en el dispositivo
  static Future<String?> _saveExcelFile(
    List<int> fileBytes,
    String fileName,
  ) async {
    try {
      // Para Flutter Web: descargar automáticamente
      if (kIsWeb) {
        final blob = html.Blob([fileBytes]);
        final url = html.Url.createObjectUrlFromBlob(blob);
        final anchor = html.AnchorElement(href: url)
          ..setAttribute('download', fileName)
          ..click();
        html.Url.revokeObjectUrl(url);

          
        return 'web_download:$fileName';
      }

      // Solicitar permisos de almacenamiento
      if (Platform.isAndroid) {
        var status = await Permission.storage.status;
        if (!status.isGranted) {
          status = await Permission.storage.request();
          if (!status.isGranted) {
            throw Exception('Permisos de almacenamiento denegados');
          }
        }
      }

      // Obtener directorio de documentos
      Directory? directory;
      if (Platform.isAndroid) {
        directory = await getExternalStorageDirectory();
      } else if (Platform.isIOS) {
        directory = await getApplicationDocumentsDirectory();
      } else {
        directory = await getApplicationDocumentsDirectory();
      }

      if (directory == null) {
        throw Exception('No se pudo acceder al directorio de almacenamiento');
      }

      // Crear ruta completa del archivo
      String filePath = '${directory.path}/$fileName';
      File file = File(filePath);

      // Escribir archivo
      await file.writeAsBytes(fileBytes);

        
      return filePath;
    } catch (e) {
        
      return null;
    }
  }

  /// Comparte el archivo Excel
  static Future<bool> compartirExcel(String filePath) async {
    try {
      final XFile file = XFile(filePath);
      await Share.shareXFiles(
        [file],
        text:
            'Contador de Efectivo - ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}',
        subject: 'Reporte de Contador de Efectivo',
      );
      return true;
    } catch (e) {
        
      return false;
    }
  }

  /// Verifica si hay datos para exportar
  static bool hayDatosParaExportar(List<DenominacionEfectivo> denominaciones) {
    return denominaciones.any((d) => d.cantidad > 0);
  }

  /// Calcula estadísticas del conteo
  static Map<String, dynamic> calcularEstadisticas(
    List<DenominacionEfectivo> denominaciones,
  ) {
    int totalItems = denominaciones.where((d) => d.cantidad > 0).length;
    int totalBilletes = denominaciones
        .where((d) => d.tipo == 'billete' && d.cantidad > 0)
        .length;
    int totalMonedas = denominaciones
        .where((d) => d.tipo == 'moneda' && d.cantidad > 0)
        .length;

    double valorTotal = ContadorEfectivo.calcularTotal(denominaciones);
    var totalesPorTipo = ContadorEfectivo.obtenerTotalesPorTipo(denominaciones);

    return {
      'totalItems': totalItems,
      'totalTiposBilletes': totalBilletes,
      'totalTiposMonedas': totalMonedas,
      'valorTotal': valorTotal,
      'valorBilletes': totalesPorTipo['billetes'],
      'valorMonedas': totalesPorTipo['monedas'],
    };
  }

  /// Exporta las estadísticas mensuales a un archivo Excel
  static Future<String?> exportarEstadisticasMensuales({
    required Map<String, dynamic> datosEstadisticas,
    String? nombreUsuario,
    String? observaciones,
  }) async {
    try {
      // Crear nuevo Excel
      var excel = Excel.createExcel();
      excel.delete('Sheet1'); // Eliminar hoja por defecto

      // Obtener información del período
      final periodoInfo =
          datosEstadisticas['periodoInfo'] as Map<String, dynamic>? ?? {};
      final mes = periodoInfo['mes'] ?? DateTime.now().month;
      final anio = periodoInfo['año'] ?? DateTime.now().year;

      // Crear hojas
      excel.copy('Sheet1', 'Resumen');
      excel.copy('Sheet1', 'Ventas');
      excel.copy('Sheet1', 'Gastos');
      excel.copy('Sheet1', 'Facturas');
      excel.copy('Sheet1', 'Top Productos');
      excel.copy('Sheet1', 'Cuadres Caja');

      // Configurar estilos
      CellStyle headerStyle = CellStyle(
        fontFamily: getFontFamily(FontFamily.Calibri),
        fontSize: 12,
        bold: true,
        backgroundColorHex: ExcelColor.blue,
        fontColorHex: ExcelColor.white,
        horizontalAlign: HorizontalAlign.Center,
      );

      CellStyle titleStyle = CellStyle(
        fontFamily: getFontFamily(FontFamily.Calibri),
        fontSize: 16,
        bold: true,
        horizontalAlign: HorizontalAlign.Center,
      );

      // Llenar hoja de resumen
      _llenarHojaResumen(
        excel['Resumen'],
        datosEstadisticas,
        titleStyle,
        headerStyle,
      );

      // Llenar hojas específicas
      _llenarHojaVentas(
        excel['Ventas'],
        datosEstadisticas,
        titleStyle,
        headerStyle,
      );
      _llenarHojaGastos(
        excel['Gastos'],
        datosEstadisticas,
        titleStyle,
        headerStyle,
      );
      _llenarHojaFacturas(
        excel['Facturas'],
        datosEstadisticas,
        titleStyle,
        headerStyle,
      );
      _llenarHojaTopProductos(
        excel['Top Productos'],
        datosEstadisticas,
        titleStyle,
        headerStyle,
      );
      _llenarHojaCuadresCaja(
        excel['Cuadres Caja'],
        datosEstadisticas,
        titleStyle,
        headerStyle,
      );

      // Generar timestamp
      String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      String fileName =
          'estadisticas_${mes.toString().padLeft(2, '0')}_${anio}_$timestamp.xlsx';

      // Codificar Excel
      final excelBytes = excel.encode();
      if (excelBytes == null) {
        throw Exception('Error al codificar el archivo Excel');
      }

      // Para Flutter Web: descargar automáticamente
      if (kIsWeb) {
        final blob = html.Blob([excelBytes]);
        final url = html.Url.createObjectUrlFromBlob(blob);
        final anchor = html.AnchorElement(href: url)
          ..setAttribute('download', fileName)
          ..click();
        html.Url.revokeObjectUrl(url);

          
        return 'web_download:$fileName';
      }

      // Para plataformas móviles
      Directory? directory;
      if (Platform.isAndroid) {
        directory = Directory('/storage/emulated/0/Download');
        if (!await directory.exists()) {
          directory = await getExternalStorageDirectory();
        }
      } else if (Platform.isIOS) {
        directory = await getApplicationDocumentsDirectory();
      }

      if (directory == null) {
        throw Exception('Error al obtener el directorio de archivos');
      }

      File file = File('${directory.path}/$fileName');
      await file.writeAsBytes(excelBytes);

        
      return file.path;
    } catch (e) {
        
      return null;
    }
  }

  // Métodos auxiliares para llenar las hojas
  static void _llenarHojaResumen(
    Sheet sheet,
    Map<String, dynamic> datos,
    CellStyle titleStyle,
    CellStyle headerStyle,
  ) {
    final periodoInfo = datos['periodoInfo'] as Map<String, dynamic>? ?? {};
    final resumenVentas = datos['resumenVentas'] as Map<String, dynamic>? ?? {};
    final resumenGastos = datos['resumenGastos'] as Map<String, dynamic>? ?? {};
    final resumenFinanciero =
        datos['resumenFinanciero'] as Map<String, dynamic>? ?? {};

    // Título
    sheet.cell(CellIndex.indexByString('A1')).value = TextCellValue(
      'RESUMEN ESTADÍSTICAS MENSUALES',
    );
    sheet.cell(CellIndex.indexByString('A1')).cellStyle = titleStyle;
    sheet.merge(CellIndex.indexByString('A1'), CellIndex.indexByString('F1'));

    // Información del período
    int row = 3;
    sheet.cell(CellIndex.indexByString('A$row')).value = TextCellValue(
      'Período:',
    );
    sheet.cell(CellIndex.indexByString('B$row')).value = TextCellValue(
      '${periodoInfo['mes']}/${periodoInfo['año']}',
    );

    row++;
    sheet.cell(CellIndex.indexByString('A$row')).value = TextCellValue(
      'Fecha de exportación:',
    );
    sheet.cell(CellIndex.indexByString('B$row')).value = TextCellValue(
      DateTime.now().toString().split('.')[0],
    );

    // Resumen financiero
    row += 2;
    sheet.cell(CellIndex.indexByString('A$row')).value = TextCellValue(
      'RESUMEN FINANCIERO',
    );
    sheet.cell(CellIndex.indexByString('A$row')).cellStyle = headerStyle;
    sheet.merge(
      CellIndex.indexByString('A$row'),
      CellIndex.indexByString('C$row'),
    );

    row++;
    sheet.cell(CellIndex.indexByString('A$row')).value = TextCellValue(
      'Total Ventas:',
    );
    sheet.cell(CellIndex.indexByString('B$row')).value = DoubleCellValue(
      double.tryParse(resumenVentas['totalVentas']?.toString() ?? '0') ?? 0,
    );

    row++;
    sheet.cell(CellIndex.indexByString('A$row')).value = TextCellValue(
      'Total Gastos:',
    );
    sheet.cell(CellIndex.indexByString('B$row')).value = DoubleCellValue(
      double.tryParse(resumenGastos['totalGastos']?.toString() ?? '0') ?? 0,
    );

    row++;
    sheet.cell(CellIndex.indexByString('A$row')).value = TextCellValue(
      'Utilidad Neta:',
    );
    sheet.cell(CellIndex.indexByString('B$row')).value = DoubleCellValue(
      double.tryParse(resumenFinanciero['utilidadNeta']?.toString() ?? '0') ??
          0,
    );

    row++;
    sheet.cell(CellIndex.indexByString('A$row')).value = TextCellValue(
      'Pedidos Pagados:',
    );
    sheet.cell(CellIndex.indexByString('B$row')).value = IntCellValue(
      int.tryParse(resumenVentas['pedidosPagados']?.toString() ?? '0') ?? 0,
    );
  }

  static void _llenarHojaVentas(
    Sheet sheet,
    Map<String, dynamic> datos,
    CellStyle titleStyle,
    CellStyle headerStyle,
  ) {
    final resumenVentas = datos['resumenVentas'] as Map<String, dynamic>? ?? {};
    final ventasDetalle =
        resumenVentas['ventasDetalle'] as List<dynamic>? ?? [];

    // Título
    sheet.cell(CellIndex.indexByString('A1')).value = TextCellValue(
      'DETALLE DE VENTAS',
    );
    sheet.cell(CellIndex.indexByString('A1')).cellStyle = titleStyle;
    sheet.merge(CellIndex.indexByString('A1'), CellIndex.indexByString('E1'));

    // Headers
    int row = 3;
    final headers = ['Fecha', 'Mesa', 'Total', 'Estado', 'Productos'];
    for (int i = 0; i < headers.length; i++) {
      String cellAddress = String.fromCharCode(65 + i) + row.toString();
      sheet.cell(CellIndex.indexByString(cellAddress)).value = TextCellValue(
        headers[i],
      );
      sheet.cell(CellIndex.indexByString(cellAddress)).cellStyle = headerStyle;
    }

    // Datos
    row++;
    for (var venta in ventasDetalle.take(100)) {
      // Limitar a 100 registros
      sheet.cell(CellIndex.indexByString('A$row')).value = TextCellValue(
        venta['fecha']?.toString() ?? '',
      );
      sheet.cell(CellIndex.indexByString('B$row')).value = TextCellValue(
        venta['mesa']?.toString() ?? '',
      );
      sheet.cell(CellIndex.indexByString('C$row')).value = DoubleCellValue(
        double.tryParse(venta['total']?.toString() ?? '0') ?? 0,
      );
      sheet.cell(CellIndex.indexByString('D$row')).value = TextCellValue(
        venta['estado']?.toString() ?? '',
      );
      sheet.cell(CellIndex.indexByString('E$row')).value = IntCellValue(
        int.tryParse(venta['cantidadProductos']?.toString() ?? '0') ?? 0,
      );
      row++;
    }
  }

  static void _llenarHojaGastos(
    Sheet sheet,
    Map<String, dynamic> datos,
    CellStyle titleStyle,
    CellStyle headerStyle,
  ) {
    final resumenGastos = datos['resumenGastos'] as Map<String, dynamic>? ?? {};
    final gastosDetalle =
        resumenGastos['gastosDetalle'] as List<dynamic>? ?? [];

    // Título
    sheet.cell(CellIndex.indexByString('A1')).value = TextCellValue(
      'DETALLE DE GASTOS',
    );
    sheet.cell(CellIndex.indexByString('A1')).cellStyle = titleStyle;
    sheet.merge(CellIndex.indexByString('A1'), CellIndex.indexByString('D1'));

    // Headers
    int row = 3;
    final headers = ['Fecha', 'Descripción', 'Monto', 'Categoría'];
    for (int i = 0; i < headers.length; i++) {
      String cellAddress = String.fromCharCode(65 + i) + row.toString();
      sheet.cell(CellIndex.indexByString(cellAddress)).value = TextCellValue(
        headers[i],
      );
      sheet.cell(CellIndex.indexByString(cellAddress)).cellStyle = headerStyle;
    }

    // Datos
    row++;
    for (var gasto in gastosDetalle.take(100)) {
      // Limitar a 100 registros
      sheet.cell(CellIndex.indexByString('A$row')).value = TextCellValue(
        gasto['fecha']?.toString() ?? '',
      );
      sheet.cell(CellIndex.indexByString('B$row')).value = TextCellValue(
        gasto['descripcion']?.toString() ?? '',
      );
      sheet.cell(CellIndex.indexByString('C$row')).value = DoubleCellValue(
        double.tryParse(gasto['monto']?.toString() ?? '0') ?? 0,
      );
      sheet.cell(CellIndex.indexByString('D$row')).value = TextCellValue(
        gasto['categoria']?.toString() ?? '',
      );
      row++;
    }
  }

  static void _llenarHojaFacturas(
    Sheet sheet,
    Map<String, dynamic> datos,
    CellStyle titleStyle,
    CellStyle headerStyle,
  ) {
    final resumenFacturas =
        datos['resumenFacturas'] as Map<String, dynamic>? ?? {};
    final facturasDetalle =
        resumenFacturas['facturasDetalle'] as List<dynamic>? ?? [];

    // Título
    sheet.cell(CellIndex.indexByString('A1')).value = TextCellValue(
      'FACTURAS DE COMPRA',
    );
    sheet.cell(CellIndex.indexByString('A1')).cellStyle = titleStyle;
    sheet.merge(CellIndex.indexByString('A1'), CellIndex.indexByString('D1'));

    // Headers
    int row = 3;
    final headers = ['Fecha', 'Proveedor', 'Total', 'Estado'];
    for (int i = 0; i < headers.length; i++) {
      String cellAddress = String.fromCharCode(65 + i) + row.toString();
      sheet.cell(CellIndex.indexByString(cellAddress)).value = TextCellValue(
        headers[i],
      );
      sheet.cell(CellIndex.indexByString(cellAddress)).cellStyle = headerStyle;
    }

    // Datos
    row++;
    for (var factura in facturasDetalle.take(100)) {
      // Limitar a 100 registros
      sheet.cell(CellIndex.indexByString('A$row')).value = TextCellValue(
        factura['fecha']?.toString() ?? '',
      );
      sheet.cell(CellIndex.indexByString('B$row')).value = TextCellValue(
        factura['proveedor']?.toString() ?? '',
      );
      sheet.cell(CellIndex.indexByString('C$row')).value = DoubleCellValue(
        double.tryParse(factura['total']?.toString() ?? '0') ?? 0,
      );
      sheet.cell(CellIndex.indexByString('D$row')).value = TextCellValue(
        factura['estado']?.toString() ?? '',
      );
      row++;
    }
  }

  static void _llenarHojaTopProductos(
    Sheet sheet,
    Map<String, dynamic> datos,
    CellStyle titleStyle,
    CellStyle headerStyle,
  ) {
    final topProductos = datos['topProductos'] as List<dynamic>? ?? [];

    // Título
    sheet.cell(CellIndex.indexByString('A1')).value = TextCellValue(
      'TOP PRODUCTOS VENDIDOS',
    );
    sheet.cell(CellIndex.indexByString('A1')).cellStyle = titleStyle;
    sheet.merge(CellIndex.indexByString('A1'), CellIndex.indexByString('D1'));

    // Headers
    int row = 3;
    final headers = [
      'Producto',
      'Cantidad Vendida',
      'Total Ventas',
      'Precio Promedio',
    ];
    for (int i = 0; i < headers.length; i++) {
      String cellAddress = String.fromCharCode(65 + i) + row.toString();
      sheet.cell(CellIndex.indexByString(cellAddress)).value = TextCellValue(
        headers[i],
      );
      sheet.cell(CellIndex.indexByString(cellAddress)).cellStyle = headerStyle;
    }

    // Datos
    row++;
    for (var producto in topProductos.take(50)) {
      // Top 50 productos
      sheet.cell(CellIndex.indexByString('A$row')).value = TextCellValue(
        producto['nombre']?.toString() ?? '',
      );
      sheet.cell(CellIndex.indexByString('B$row')).value = IntCellValue(
        int.tryParse(producto['cantidadVendida']?.toString() ?? '0') ?? 0,
      );
      sheet.cell(CellIndex.indexByString('C$row')).value = DoubleCellValue(
        double.tryParse(producto['totalVentas']?.toString() ?? '0') ?? 0,
      );
      sheet.cell(CellIndex.indexByString('D$row')).value = DoubleCellValue(
        double.tryParse(producto['precioPromedio']?.toString() ?? '0') ?? 0,
      );
      row++;
    }
  }

  static void _llenarHojaCuadresCaja(
    Sheet sheet,
    Map<String, dynamic> datos,
    CellStyle titleStyle,
    CellStyle headerStyle,
  ) {
    final cuadresCaja = datos['cuadresCaja'] as List<dynamic>? ?? [];

    // Título
    sheet.cell(CellIndex.indexByString('A1')).value = TextCellValue(
      'CUADRES DE CAJA',
    );
    sheet.cell(CellIndex.indexByString('A1')).cellStyle = titleStyle;
    sheet.merge(CellIndex.indexByString('A1'), CellIndex.indexByString('E1'));

    // Headers
    int row = 3;
    final headers = [
      'Fecha',
      'Efectivo Inicial',
      'Ventas',
      'Gastos',
      'Efectivo Final',
    ];
    for (int i = 0; i < headers.length; i++) {
      String cellAddress = String.fromCharCode(65 + i) + row.toString();
      sheet.cell(CellIndex.indexByString(cellAddress)).value = TextCellValue(
        headers[i],
      );
      sheet.cell(CellIndex.indexByString(cellAddress)).cellStyle = headerStyle;
    }

    // Datos
    row++;
    for (var cuadre in cuadresCaja.take(100)) {
      // Limitar a 100 registros
      sheet.cell(CellIndex.indexByString('A$row')).value = TextCellValue(
        cuadre['fecha']?.toString() ?? '',
      );
      sheet.cell(CellIndex.indexByString('B$row')).value = DoubleCellValue(
        double.tryParse(cuadre['efectivoInicial']?.toString() ?? '0') ?? 0,
      );
      sheet.cell(CellIndex.indexByString('C$row')).value = DoubleCellValue(
        double.tryParse(cuadre['totalVentas']?.toString() ?? '0') ?? 0,
      );
      sheet.cell(CellIndex.indexByString('D$row')).value = DoubleCellValue(
        double.tryParse(cuadre['totalGastos']?.toString() ?? '0') ?? 0,
      );
      sheet.cell(CellIndex.indexByString('E$row')).value = DoubleCellValue(
        double.tryParse(cuadre['efectivoFinal']?.toString() ?? '0') ?? 0,
      );
      row++;
    }
  }

  /// Verifica si hay datos de estadísticas para exportar
  static bool hayDatosEstadisticasParaExportar(Map<String, dynamic>? datos) {
    if (datos == null) return false;

    final resumenVentas = datos['resumenVentas'] as Map<String, dynamic>?;
    final resumenGastos = datos['resumenGastos'] as Map<String, dynamic>?;

    // Verificar si hay ventas o gastos
    final tieneVentas =
        resumenVentas != null &&
        (double.tryParse(resumenVentas['totalVentas']?.toString() ?? '0') ??
                0) >
            0;
    final tieneGastos =
        resumenGastos != null &&
        (double.tryParse(resumenGastos['totalGastos']?.toString() ?? '0') ??
                0) >
            0;

    return tieneVentas || tieneGastos;
  }

  // ==================== LIBRO CONTABLE MENSUAL ====================

  /// Exporta el libro contable mensual a un archivo Excel: ventas de
  /// Facturación Electrónica + POS separadas de ventas Locales (desglosadas
  /// por medio de pago detallado), más Compras y Gastos del mes.
  static Future<String?> exportarLibroContable({
    required Map<String, dynamic> datosLibroContable,
    String? nombreUsuario,
    String? observaciones,
    // Opcionales: solo disponibles cuando se exporta desde el tab "Resumen"
    // (que ya carga rentabilidad por producto sin mano de obra y
    // recomendaciones); si vienen null se omite esa hoja, sin romper el
    // export más simple del tab "Ventas y Gastos".
    Map<String, dynamic>? rentabilidadProductosSinManoDeObra,
    List<dynamic>? recomendaciones,
  }) async {
    try {
      var excel = Excel.createExcel();
      excel.delete('Sheet1');

      final periodoInfo =
          datosLibroContable['periodoInfo'] as Map<String, dynamic>? ?? {};
      final mes = periodoInfo['mes'] ?? DateTime.now().month;
      final anio = periodoInfo['anio'] ?? DateTime.now().year;

      excel.copy('Sheet1', 'Resumen');
      excel.copy('Sheet1', 'Ventas FE y POS');
      excel.copy('Sheet1', 'Ventas Locales');
      excel.copy('Sheet1', 'Compras');
      excel.copy('Sheet1', 'Gastos');
      if (rentabilidadProductosSinManoDeObra != null || recomendaciones != null) {
        excel.copy('Sheet1', 'Resumen Narrativo');
      }

      CellStyle headerStyle = CellStyle(
        fontFamily: getFontFamily(FontFamily.Calibri),
        fontSize: 12,
        bold: true,
        backgroundColorHex: ExcelColor.blue,
        fontColorHex: ExcelColor.white,
        horizontalAlign: HorizontalAlign.Center,
      );

      CellStyle titleStyle = CellStyle(
        fontFamily: getFontFamily(FontFamily.Calibri),
        fontSize: 16,
        bold: true,
        horizontalAlign: HorizontalAlign.Center,
      );

      _llenarHojaResumenLibroContable(
        excel['Resumen'],
        datosLibroContable,
        titleStyle,
        headerStyle,
      );
      _llenarHojaVentasPorMedioPago(
        excel['Ventas FE y POS'],
        datosLibroContable['ventasElectronicasFEyPOS'] as Map<String, dynamic>? ?? {},
        'VENTAS - FACTURACIÓN ELECTRÓNICA Y POS',
        titleStyle,
        headerStyle,
      );
      _llenarHojaVentasPorMedioPago(
        excel['Ventas Locales'],
        datosLibroContable['ventasLocales'] as Map<String, dynamic>? ?? {},
        'VENTAS - FACTURAS LOCALES',
        titleStyle,
        headerStyle,
      );
      _llenarHojaComprasLibroContable(
        excel['Compras'],
        datosLibroContable,
        titleStyle,
        headerStyle,
      );
      _llenarHojaGastosLibroContable(
        excel['Gastos'],
        datosLibroContable,
        titleStyle,
        headerStyle,
      );
      if (rentabilidadProductosSinManoDeObra != null || recomendaciones != null) {
        _llenarHojaResumenNarrativo(
          excel['Resumen Narrativo'],
          datosLibroContable,
          rentabilidadProductosSinManoDeObra,
          recomendaciones,
          titleStyle,
          headerStyle,
        );
      }

      String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      String fileName =
          'libro_contable_${mes.toString().padLeft(2, '0')}_${anio}_$timestamp.xlsx';

      final excelBytes = excel.encode();
      if (excelBytes == null) {
        throw Exception('Error al codificar el archivo Excel');
      }

      if (kIsWeb) {
        final blob = html.Blob([excelBytes]);
        final url = html.Url.createObjectUrlFromBlob(blob);
        final anchor = html.AnchorElement(href: url)
          ..setAttribute('download', fileName)
          ..click();
        html.Url.revokeObjectUrl(url);
        return 'web_download:$fileName';
      }

      Directory? directory;
      if (Platform.isAndroid) {
        directory = Directory('/storage/emulated/0/Download');
        if (!await directory.exists()) {
          directory = await getExternalStorageDirectory();
        }
      } else if (Platform.isIOS) {
        directory = await getApplicationDocumentsDirectory();
      }

      if (directory == null) {
        throw Exception('Error al obtener el directorio de archivos');
      }

      File file = File('${directory.path}/$fileName');
      await file.writeAsBytes(excelBytes);
      return file.path;
    } catch (e) {
      return null;
    }
  }

  static void _llenarHojaResumenLibroContable(
    Sheet sheet,
    Map<String, dynamic> datos,
    CellStyle titleStyle,
    CellStyle headerStyle,
  ) {
    final periodoInfo = datos['periodoInfo'] as Map<String, dynamic>? ?? {};
    final ventasFEyPOS =
        datos['ventasElectronicasFEyPOS'] as Map<String, dynamic>? ?? {};
    final ventasLocales = datos['ventasLocales'] as Map<String, dynamic>? ?? {};
    final compras = datos['compras'] as Map<String, dynamic>? ?? {};
    final gastos = datos['gastos'] as Map<String, dynamic>? ?? {};

    sheet.cell(CellIndex.indexByString('A1')).value = TextCellValue(
      'LIBRO CONTABLE MENSUAL',
    );
    sheet.cell(CellIndex.indexByString('A1')).cellStyle = titleStyle;
    sheet.merge(CellIndex.indexByString('A1'), CellIndex.indexByString('C1'));

    int row = 3;
    sheet.cell(CellIndex.indexByString('A$row')).value = TextCellValue('Período:');
    sheet.cell(CellIndex.indexByString('B$row')).value = TextCellValue(
      '${periodoInfo['mes']}/${periodoInfo['anio']}',
    );

    row += 2;
    sheet.cell(CellIndex.indexByString('A$row')).value = TextCellValue(
      'RESUMEN',
    );
    sheet.cell(CellIndex.indexByString('A$row')).cellStyle = headerStyle;
    sheet.merge(
      CellIndex.indexByString('A$row'),
      CellIndex.indexByString('B$row'),
    );

    row++;
    sheet.cell(CellIndex.indexByString('A$row')).value = TextCellValue(
      'Ingresos Facturación Electrónica y POS:',
    );
    sheet.cell(CellIndex.indexByString('B$row')).value = DoubleCellValue(
      double.tryParse(ventasFEyPOS['total']?.toString() ?? '0') ?? 0,
    );

    row++;
    sheet.cell(CellIndex.indexByString('A$row')).value = TextCellValue(
      'Ventas Facturas Locales:',
    );
    sheet.cell(CellIndex.indexByString('B$row')).value = DoubleCellValue(
      double.tryParse(ventasLocales['total']?.toString() ?? '0') ?? 0,
    );

    row++;
    sheet.cell(CellIndex.indexByString('A$row')).value = TextCellValue(
      'Compras:',
    );
    sheet.cell(CellIndex.indexByString('B$row')).value = DoubleCellValue(
      double.tryParse(compras['total']?.toString() ?? '0') ?? 0,
    );

    row++;
    sheet.cell(CellIndex.indexByString('A$row')).value = TextCellValue(
      'Gastos:',
    );
    sheet.cell(CellIndex.indexByString('B$row')).value = DoubleCellValue(
      double.tryParse(gastos['total']?.toString() ?? '0') ?? 0,
    );
  }

  /// Hoja compartida por "Ventas FE y POS" y "Ventas Locales": desglosa el
  /// total por medio de pago detallado (Nequi, DaviPlata, Bancolombia, Bold,
  /// Sistecredito, Addi, Credilondon, Efectivo, etc.).
  static void _llenarHojaVentasPorMedioPago(
    Sheet sheet,
    Map<String, dynamic> seccionVentas,
    String titulo,
    CellStyle titleStyle,
    CellStyle headerStyle,
  ) {
    final porMedioPago =
        seccionVentas['porMedioPago'] as Map<String, dynamic>? ?? {};

    sheet.cell(CellIndex.indexByString('A1')).value = TextCellValue(titulo);
    sheet.cell(CellIndex.indexByString('A1')).cellStyle = titleStyle;
    sheet.merge(CellIndex.indexByString('A1'), CellIndex.indexByString('D1'));

    int row = 3;
    sheet.cell(CellIndex.indexByString('A$row')).value = TextCellValue('Total:');
    sheet.cell(CellIndex.indexByString('B$row')).value = DoubleCellValue(
      double.tryParse(seccionVentas['total']?.toString() ?? '0') ?? 0,
    );
    sheet.cell(CellIndex.indexByString('C$row')).value = TextCellValue(
      'Cantidad:',
    );
    sheet.cell(CellIndex.indexByString('D$row')).value = IntCellValue(
      int.tryParse(seccionVentas['cantidad']?.toString() ?? '0') ?? 0,
    );

    row += 2;
    final headers = ['Medio de Pago', 'Monto', 'Cantidad', '% del Total'];
    for (int i = 0; i < headers.length; i++) {
      String cellAddress = String.fromCharCode(65 + i) + row.toString();
      sheet.cell(CellIndex.indexByString(cellAddress)).value = TextCellValue(
        headers[i],
      );
      sheet.cell(CellIndex.indexByString(cellAddress)).cellStyle = headerStyle;
    }

    row++;
    for (var entry in porMedioPago.entries) {
      final detalle = entry.value as Map<String, dynamic>? ?? {};
      sheet.cell(CellIndex.indexByString('A$row')).value = TextCellValue(
        entry.key,
      );
      sheet.cell(CellIndex.indexByString('B$row')).value = DoubleCellValue(
        double.tryParse(detalle['monto']?.toString() ?? '0') ?? 0,
      );
      sheet.cell(CellIndex.indexByString('C$row')).value = IntCellValue(
        int.tryParse(detalle['cantidad']?.toString() ?? '0') ?? 0,
      );
      sheet.cell(CellIndex.indexByString('D$row')).value = DoubleCellValue(
        double.tryParse(detalle['porcentaje']?.toString() ?? '0') ?? 0,
      );
      row++;
    }

    // El total de "Mixto" ya quedó como una fila arriba (monto completo, sin
    // partir) — acá se agrega, aparte, de qué submétodos reales estaba
    // compuesto ese monto (efectivo/transferencia/etc. dentro del mismo pago
    // mixto). Antes el Excel no traía esta información en absoluto.
    final desgloseMixto =
        seccionVentas['desgloseMixto'] as Map<String, dynamic>? ?? {};
    if (desgloseMixto.isNotEmpty) {
      row++;
      sheet.cell(CellIndex.indexByString('A$row')).value = TextCellValue(
        'Desglose de "Mixto" por submétodo:',
      );
      sheet.cell(CellIndex.indexByString('A$row')).cellStyle = headerStyle;
      row++;
      for (var entry in desgloseMixto.entries) {
        final detalle = entry.value as Map<String, dynamic>? ?? {};
        sheet.cell(CellIndex.indexByString('A$row')).value = TextCellValue(
          '  ${entry.key}',
        );
        sheet.cell(CellIndex.indexByString('B$row')).value = DoubleCellValue(
          double.tryParse(detalle['monto']?.toString() ?? '0') ?? 0,
        );
        sheet.cell(CellIndex.indexByString('C$row')).value = IntCellValue(
          int.tryParse(detalle['cantidad']?.toString() ?? '0') ?? 0,
        );
        sheet.cell(CellIndex.indexByString('D$row')).value = DoubleCellValue(
          double.tryParse(detalle['porcentaje']?.toString() ?? '0') ?? 0,
        );
        row++;
      }
    }
  }

  /// Escribe un bloque de desglose (clave → monto/cantidad) empezando en
  /// [startRow] y devuelve la siguiente fila libre (con una línea en blanco
  /// de separación). Usado para "por medio de pago" / "por proveedor" /
  /// "por concepto" en las hojas de Compras y Gastos del libro contable.
  static int _escribirDesglose(
    Sheet sheet,
    Map<String, dynamic> seccion,
    String key,
    String titulo,
    int startRow,
    CellStyle headerStyle,
  ) {
    final datos = seccion[key] as Map<String, dynamic>? ?? {};
    int row = startRow;
    sheet.cell(CellIndex.indexByString('A$row')).value = TextCellValue(titulo);
    sheet.cell(CellIndex.indexByString('A$row')).cellStyle = headerStyle;
    sheet.merge(CellIndex.indexByString('A$row'), CellIndex.indexByString('C$row'));
    row++;
    for (var entry in datos.entries) {
      final detalle = entry.value as Map<String, dynamic>? ?? {};
      sheet.cell(CellIndex.indexByString('A$row')).value = TextCellValue(entry.key);
      sheet.cell(CellIndex.indexByString('B$row')).value = DoubleCellValue(
        double.tryParse(detalle['monto']?.toString() ?? '0') ?? 0,
      );
      sheet.cell(CellIndex.indexByString('C$row')).value = IntCellValue(
        int.tryParse(detalle['cantidad']?.toString() ?? '0') ?? 0,
      );
      row++;
    }
    return row + 1;
  }

  static void _llenarHojaComprasLibroContable(
    Sheet sheet,
    Map<String, dynamic> datos,
    CellStyle titleStyle,
    CellStyle headerStyle,
  ) {
    final compras = datos['compras'] as Map<String, dynamic>? ?? {};
    final detalle = compras['detalle'] as List<dynamic>? ?? [];

    sheet.cell(CellIndex.indexByString('A1')).value = TextCellValue('COMPRAS');
    sheet.cell(CellIndex.indexByString('A1')).cellStyle = titleStyle;
    sheet.merge(CellIndex.indexByString('A1'), CellIndex.indexByString('D1'));

    int row = _escribirDesglose(sheet, compras, 'porMedioPago', 'Por medio de pago', 3, headerStyle);
    row = _escribirDesglose(sheet, compras, 'porProveedor', 'Por proveedor', row, headerStyle);

    final headers = ['Fecha', 'Proveedor', 'Total', 'Método de Pago'];
    for (int i = 0; i < headers.length; i++) {
      String cellAddress = String.fromCharCode(65 + i) + row.toString();
      sheet.cell(CellIndex.indexByString(cellAddress)).value = TextCellValue(
        headers[i],
      );
      sheet.cell(CellIndex.indexByString(cellAddress)).cellStyle = headerStyle;
    }

    row++;
    for (var compra in detalle.take(200)) {
      sheet.cell(CellIndex.indexByString('A$row')).value = TextCellValue(
        compra['fechaCreacion']?.toString() ?? '',
      );
      sheet.cell(CellIndex.indexByString('B$row')).value = TextCellValue(
        compra['proveedorNombre']?.toString() ?? '',
      );
      sheet.cell(CellIndex.indexByString('C$row')).value = DoubleCellValue(
        double.tryParse(compra['total']?.toString() ?? '0') ?? 0,
      );
      sheet.cell(CellIndex.indexByString('D$row')).value = TextCellValue(
        compra['metodoPago']?.toString() ?? '',
      );
      row++;
    }
  }

  static void _llenarHojaGastosLibroContable(
    Sheet sheet,
    Map<String, dynamic> datos,
    CellStyle titleStyle,
    CellStyle headerStyle,
  ) {
    final gastos = datos['gastos'] as Map<String, dynamic>? ?? {};
    final detalle = gastos['detalle'] as List<dynamic>? ?? [];

    sheet.cell(CellIndex.indexByString('A1')).value = TextCellValue('GASTOS');
    sheet.cell(CellIndex.indexByString('A1')).cellStyle = titleStyle;
    sheet.merge(CellIndex.indexByString('A1'), CellIndex.indexByString('D1'));

    int row = _escribirDesglose(sheet, gastos, 'porMedioPago', 'Por medio de pago', 3, headerStyle);
    row = _escribirDesglose(sheet, gastos, 'porConcepto', 'Por concepto', row, headerStyle);

    final headers = ['Fecha', 'Concepto', 'Monto', 'Forma de Pago'];
    for (int i = 0; i < headers.length; i++) {
      String cellAddress = String.fromCharCode(65 + i) + row.toString();
      sheet.cell(CellIndex.indexByString(cellAddress)).value = TextCellValue(
        headers[i],
      );
      sheet.cell(CellIndex.indexByString(cellAddress)).cellStyle = headerStyle;
    }

    row++;
    for (var gasto in detalle.take(200)) {
      sheet.cell(CellIndex.indexByString('A$row')).value = TextCellValue(
        gasto['fechaGasto']?.toString() ?? '',
      );
      sheet.cell(CellIndex.indexByString('B$row')).value = TextCellValue(
        gasto['concepto']?.toString() ?? '',
      );
      sheet.cell(CellIndex.indexByString('C$row')).value = DoubleCellValue(
        double.tryParse(gasto['monto']?.toString() ?? '0') ?? 0,
      );
      sheet.cell(CellIndex.indexByString('D$row')).value = TextCellValue(
        gasto['formaPago']?.toString() ?? '',
      );
      row++;
    }
  }

  /// Hoja adicional del tab "Resumen": gastos por naturaleza (fijo/variable/
  /// mixto, ya viene en [datosLibroContable]), compras como % de ventas,
  /// ventas por producto sin mano de obra, y las recomendaciones en texto —
  /// mismo contenido que se ve en pantalla, en formato exportable.
  static void _llenarHojaResumenNarrativo(
    Sheet sheet,
    Map<String, dynamic> datosLibroContable,
    Map<String, dynamic>? rentabilidadProductos,
    List<dynamic>? recomendaciones,
    CellStyle titleStyle,
    CellStyle headerStyle,
  ) {
    sheet.cell(CellIndex.indexByString('A1')).value = TextCellValue('RESUMEN NARRATIVO');
    sheet.cell(CellIndex.indexByString('A1')).cellStyle = titleStyle;
    sheet.merge(CellIndex.indexByString('A1'), CellIndex.indexByString('D1'));

    int row = 3;
    final gastos = datosLibroContable['gastos'] as Map<String, dynamic>? ?? {};
    row = _escribirDesglose(sheet, gastos, 'porNaturaleza', 'Gastos por naturaleza (fijo/variable/mixto)', row, headerStyle);

    row++;
    sheet.cell(CellIndex.indexByString('A$row')).value = TextCellValue('Compras como % de ventas:');
    sheet.cell(CellIndex.indexByString('B$row')).value = DoubleCellValue(
      double.tryParse(datosLibroContable['comprasComoPorcentajeVentas']?.toString() ?? '0') ?? 0,
    );
    row += 2;

    if (rentabilidadProductos != null) {
      sheet.cell(CellIndex.indexByString('A$row')).value = TextCellValue('VENTAS POR PRODUCTO (SIN MANO DE OBRA)');
      sheet.cell(CellIndex.indexByString('A$row')).cellStyle = headerStyle;
      sheet.merge(CellIndex.indexByString('A$row'), CellIndex.indexByString('C$row'));
      row++;

      final headers = ['Producto', 'Cantidad Vendida', 'Ventas'];
      for (int i = 0; i < headers.length; i++) {
        final cellAddress = String.fromCharCode(65 + i) + row.toString();
        sheet.cell(CellIndex.indexByString(cellAddress)).value = TextCellValue(headers[i]);
        sheet.cell(CellIndex.indexByString(cellAddress)).cellStyle = headerStyle;
      }
      row++;

      final porCantidad = rentabilidadProductos['porCantidadVendida'] as List<dynamic>? ?? [];
      for (var producto in porCantidad) {
        final mapa = producto as Map<String, dynamic>;
        sheet.cell(CellIndex.indexByString('A$row')).value = TextCellValue(
          mapa['productoNombre']?.toString() ?? '',
        );
        sheet.cell(CellIndex.indexByString('B$row')).value = DoubleCellValue(
          double.tryParse(mapa['cantidadVendida']?.toString() ?? '0') ?? 0,
        );
        sheet.cell(CellIndex.indexByString('C$row')).value = DoubleCellValue(
          double.tryParse(mapa['ventas']?.toString() ?? '0') ?? 0,
        );
        row++;
      }
      row++;
    }

    if (recomendaciones != null) {
      sheet.cell(CellIndex.indexByString('A$row')).value = TextCellValue('RECOMENDACIONES');
      sheet.cell(CellIndex.indexByString('A$row')).cellStyle = headerStyle;
      sheet.merge(CellIndex.indexByString('A$row'), CellIndex.indexByString('D$row'));
      row++;

      for (var recomendacion in recomendaciones) {
        final mapa = recomendacion as Map<String, dynamic>;
        sheet.cell(CellIndex.indexByString('A$row')).value = TextCellValue(
          mapa['categoria']?.toString() ?? '',
        );
        sheet.cell(CellIndex.indexByString('B$row')).value = TextCellValue(
          mapa['mensaje']?.toString() ?? '',
        );
        sheet.merge(CellIndex.indexByString('B$row'), CellIndex.indexByString('D$row'));
        row++;
      }
    }
  }

  /// Verifica si hay datos del libro contable para exportar
  static bool hayDatosLibroContableParaExportar(Map<String, dynamic>? datos) {
    if (datos == null) return false;

    final ventasFEyPOS =
        datos['ventasElectronicasFEyPOS'] as Map<String, dynamic>?;
    final ventasLocales = datos['ventasLocales'] as Map<String, dynamic>?;
    final compras = datos['compras'] as Map<String, dynamic>?;
    final gastos = datos['gastos'] as Map<String, dynamic>?;

    double totalDe(Map<String, dynamic>? seccion) =>
        double.tryParse(seccion?['total']?.toString() ?? '0') ?? 0;

    return totalDe(ventasFEyPOS) > 0 ||
        totalDe(ventasLocales) > 0 ||
        totalDe(compras) > 0 ||
        totalDe(gastos) > 0;
  }

  /// Exporta la lista de documentos (facturas electrónicas, POS y facturas
  /// locales) de la pantalla "Documentos" a un Excel detallado: una fila por
  /// documento con su IVA, y al final un subtotal por tipo de documento más
  /// el total acumulado general.
  ///
  /// Cada elemento de [documentos] debe traer: tipo, numero, cliente, fecha,
  /// total, iva, abono, saldo, estado.
  static Future<String?> exportarDocumentos(
    List<Map<String, dynamic>> documentos, {
    String? rangoFechas,
  }) async {
    try {
      var excel = Excel.createExcel();
      Sheet sheet = excel['Documentos'];
      excel.delete('Sheet1');

      CellStyle titleStyle = CellStyle(
        fontFamily: getFontFamily(FontFamily.Calibri),
        fontSize: 16,
        bold: true,
        horizontalAlign: HorizontalAlign.Center,
      );

      CellStyle headerStyle = CellStyle(
        fontFamily: getFontFamily(FontFamily.Calibri),
        fontSize: 12,
        bold: true,
        backgroundColorHex: ExcelColor.blue,
        fontColorHex: ExcelColor.white,
        horizontalAlign: HorizontalAlign.Center,
      );

      CellStyle dataStyle = CellStyle(
        fontFamily: getFontFamily(FontFamily.Calibri),
        fontSize: 11,
      );

      CellStyle dataMoneyStyle = CellStyle(
        fontFamily: getFontFamily(FontFamily.Calibri),
        fontSize: 11,
        horizontalAlign: HorizontalAlign.Right,
      );

      CellStyle subtotalStyle = CellStyle(
        fontFamily: getFontFamily(FontFamily.Calibri),
        fontSize: 11,
        bold: true,
        horizontalAlign: HorizontalAlign.Right,
      );

      CellStyle subtotalLabelStyle = CellStyle(
        fontFamily: getFontFamily(FontFamily.Calibri),
        fontSize: 11,
        bold: true,
      );

      CellStyle totalStyle = CellStyle(
        fontFamily: getFontFamily(FontFamily.Calibri),
        fontSize: 12,
        bold: true,
        backgroundColorHex: ExcelColor.green,
        fontColorHex: ExcelColor.white,
        horizontalAlign: HorizontalAlign.Right,
      );

      CellStyle totalLabelStyle = CellStyle(
        fontFamily: getFontFamily(FontFamily.Calibri),
        fontSize: 12,
        bold: true,
        backgroundColorHex: ExcelColor.green,
        fontColorHex: ExcelColor.white,
      );

      const columnas = [
        'Tipo',
        'N. Documento',
        'Cliente',
        'Expedición',
        'Total',
        'Total sin IVA',
        'IVA',
        'Estado',
      ];
      final anchos = [10.0, 18.0, 30.0, 14.0, 15.0, 15.0, 15.0, 14.0];
      for (var i = 0; i < anchos.length; i++) {
        sheet.setColumnWidth(i, anchos[i]);
      }

      int row = 0;

      // Título
      sheet.merge(
        CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row),
        CellIndex.indexByColumnRow(columnIndex: columnas.length - 1, rowIndex: row),
      );
      var titleCell = sheet.cell(
        CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row),
      );
      titleCell.value = TextCellValue(
        rangoFechas != null && rangoFechas.isNotEmpty
            ? 'LISTA DE DOCUMENTOS ($rangoFechas)'
            : 'LISTA DE DOCUMENTOS',
      );
      titleCell.cellStyle = titleStyle;
      row++;

      var fechaGeneracionCell = sheet.cell(
        CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row),
      );
      fechaGeneracionCell.value = TextCellValue(
        'Generado: ${DateTime.now().day.toString().padLeft(2, '0')}/${DateTime.now().month.toString().padLeft(2, '0')}/${DateTime.now().year}',
      );
      fechaGeneracionCell.cellStyle = dataStyle;
      row += 2;

      // Encabezados
      for (var i = 0; i < columnas.length; i++) {
        var headerCell = sheet.cell(
          CellIndex.indexByColumnRow(columnIndex: i, rowIndex: row),
        );
        headerCell.value = TextCellValue(columnas[i]);
        headerCell.cellStyle = headerStyle;
      }
      row++;

      // Filas de documentos + acumulación de totales por tipo
      final totalesPorTipo = <String, Map<String, double>>{};
      double granTotal = 0, granTotalSinIva = 0, granIva = 0;

      for (final doc in documentos) {
        final tipo = (doc['tipo'] ?? '').toString();
        final total = (doc['total'] as num?)?.toDouble() ?? 0.0;
        final iva = (doc['iva'] as num?)?.toDouble() ?? 0.0;
        // El total sin IVA se deriva de total - iva en vez de pedir un valor
        // aparte: como iva ya viene de la misma fuente que reporta Matías
        // (totalImpuestos del pedido, o el desglose real de la factura DIAN),
        // esta resta coincide con el "tax_exclusive_amount" que Matías calcula.
        final totalSinIva = total - iva;

        final valores = <dynamic>[
          tipo,
          (doc['numero'] ?? '').toString(),
          (doc['cliente'] ?? '').toString(),
          (doc['fecha'] ?? '').toString(),
          total,
          totalSinIva,
          iva,
          (doc['estado'] ?? '').toString(),
        ];

        for (var i = 0; i < valores.length; i++) {
          final cell = sheet.cell(
            CellIndex.indexByColumnRow(columnIndex: i, rowIndex: row),
          );
          final valor = valores[i];
          if (valor is double) {
            cell.value = DoubleCellValue(valor);
            cell.cellStyle = dataMoneyStyle;
          } else {
            cell.value = TextCellValue(valor as String);
            cell.cellStyle = dataStyle;
          }
        }
        row++;

        final acumulado = totalesPorTipo.putIfAbsent(
          tipo.isEmpty ? 'OTROS' : tipo,
          () => {'total': 0, 'totalSinIva': 0, 'iva': 0},
        );
        acumulado['total'] = acumulado['total']! + total;
        acumulado['totalSinIva'] = acumulado['totalSinIva']! + totalSinIva;
        acumulado['iva'] = acumulado['iva']! + iva;

        granTotal += total;
        granTotalSinIva += totalSinIva;
        granIva += iva;
      }

      row++; // Fila en blanco antes de los totales

      // Subtotal por tipo de documento (POS, FE, FACTURA, ...)
      final tiposOrdenados = totalesPorTipo.keys.toList()..sort();
      for (final tipo in tiposOrdenados) {
        final acumulado = totalesPorTipo[tipo]!;

        var labelCell = sheet.cell(
          CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row),
        );
        labelCell.value = TextCellValue('Total $tipo');
        labelCell.cellStyle = subtotalLabelStyle;
        sheet.merge(
          CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row),
          CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: row),
        );

        final subtotalValores = [
          acumulado['total']!,
          acumulado['totalSinIva']!,
          acumulado['iva']!,
        ];
        for (var i = 0; i < subtotalValores.length; i++) {
          final cell = sheet.cell(
            CellIndex.indexByColumnRow(columnIndex: 4 + i, rowIndex: row),
          );
          cell.value = DoubleCellValue(subtotalValores[i]);
          cell.cellStyle = subtotalStyle;
        }
        row++;
      }

      row++; // Fila en blanco antes del total general

      // Total general acumulado
      var totalGeneralLabel = sheet.cell(
        CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row),
      );
      totalGeneralLabel.value = TextCellValue('TOTAL GENERAL');
      totalGeneralLabel.cellStyle = totalLabelStyle;
      sheet.merge(
        CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row),
        CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: row),
      );

      final totalGeneralValores = [granTotal, granTotalSinIva, granIva];
      for (var i = 0; i < totalGeneralValores.length; i++) {
        final cell = sheet.cell(
          CellIndex.indexByColumnRow(columnIndex: 4 + i, rowIndex: row),
        );
        cell.value = DoubleCellValue(totalGeneralValores[i]);
        cell.cellStyle = totalStyle;
      }

      final fileBytes = excel.save();
      if (fileBytes == null) {
        throw Exception('Error al generar el archivo Excel');
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      final sufijoRango = rangoFechas != null && rangoFechas.isNotEmpty
          ? '_${rangoFechas.replaceAll('/', '-').replaceAll(' ', '')}'
          : '';
      final fileName = 'documentos${sufijoRango}_$timestamp.xlsx';
      return await _saveExcelFileConDialogo(fileBytes, fileName);
    } catch (e) {
      return null;
    }
  }

  /// Guarda un archivo Excel ya generado. En web descarga el blob, en
  /// Android/iOS usa el almacenamiento del dispositivo (igual que
  /// [_saveExcelFile]) y en desktop (Windows/macOS/Linux) abre el diálogo
  /// nativo "Guardar como" con [FilePicker], ya que allí no existe una
  /// carpeta de Descargas accesible por defecto vía path_provider.
  static Future<String?> _saveExcelFileConDialogo(
    List<int> fileBytes,
    String fileName,
  ) async {
    if (kIsWeb) {
      final blob = html.Blob([fileBytes]);
      final url = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.AnchorElement(href: url)
        ..setAttribute('download', fileName)
        ..click();
      html.Url.revokeObjectUrl(url);
      return 'web_download:$fileName';
    }

    if (Platform.isAndroid || Platform.isIOS) {
      return _saveExcelFile(fileBytes, fileName);
    }

    // Desktop: dejar que el usuario elija dónde guardar el archivo.
    final String? path = await FilePicker.platform.saveFile(
      dialogTitle: 'Guardar Excel',
      fileName: fileName,
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
      bytes: Uint8List.fromList(fileBytes),
    );
    if (path == null) return null; // El usuario canceló el diálogo

    final file = File(path);
    await file.writeAsBytes(fileBytes, flush: true);
    return file.path;
  }
}
