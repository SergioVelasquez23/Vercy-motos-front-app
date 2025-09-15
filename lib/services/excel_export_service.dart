import 'dart:io';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';
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
      print('❌ Error exportando Excel: $e');
      return null;
    }
  }

  /// Guarda el archivo Excel en el dispositivo
  static Future<String?> _saveExcelFile(
    List<int> fileBytes,
    String fileName,
  ) async {
    try {
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

      print('✅ Archivo Excel guardado en: $filePath');
      return filePath;
    } catch (e) {
      print('❌ Error guardando archivo: $e');
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
      print('❌ Error compartiendo Excel: $e');
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
}
