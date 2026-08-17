import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

String formatearFechaCorta(DateTime fecha) => DateFormat('dd/MM/yyyy').format(fecha);

/// Diálogo para elegir un rango de fechas "Desde"/"Hasta" con showDatePicker
/// nativo, usado por los reportes de Libro Contable y Costeo de Inventario.
Future<DateTimeRange?> mostrarSelectorRangoFechas(
  BuildContext context, {
  required String titulo,
  DateTimeRange? valorInicial,
}) async {
  DateTime desde = valorInicial?.start ?? DateTime.now().subtract(const Duration(days: 30));
  DateTime hasta = valorInicial?.end ?? DateTime.now();

  return showDialog<DateTimeRange>(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          Future<void> seleccionar(bool esDesde) async {
            final fecha = await showDatePicker(
              context: dialogContext,
              initialDate: esDesde ? desde : hasta,
              firstDate: DateTime(2020),
              lastDate: DateTime.now(),
            );
            if (fecha != null) {
              setDialogState(() {
                if (esDesde) {
                  desde = fecha;
                } else {
                  hasta = fecha;
                }
              });
            }
          }

          return AlertDialog(
            title: Text(titulo),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Selecciona el rango de fechas a calcular:',
                  style: TextStyle(fontSize: 13, color: Colors.grey),
                ),
                const SizedBox(height: 8),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Desde'),
                  subtitle: Text(
                    formatearFechaCorta(desde),
                    style: TextStyle(color: Theme.of(dialogContext).primaryColor, fontWeight: FontWeight.bold),
                  ),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () => seleccionar(true),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Hasta'),
                  subtitle: Text(
                    formatearFechaCorta(hasta),
                    style: TextStyle(color: Theme.of(dialogContext).primaryColor, fontWeight: FontWeight.bold),
                  ),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () => seleccionar(false),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Cancelar'),
              ),
              ElevatedButton.icon(
                onPressed: () {
                  if (hasta.isBefore(desde)) {
                    ScaffoldMessenger.of(dialogContext).showSnackBar(
                      const SnackBar(content: Text('La fecha "Hasta" no puede ser anterior a "Desde"')),
                    );
                    return;
                  }
                  Navigator.of(dialogContext).pop(DateTimeRange(start: desde, end: hasta));
                },
                icon: const Icon(Icons.calculate),
                label: const Text('Calcular'),
              ),
            ],
          );
        },
      );
    },
  );
}
