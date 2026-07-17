import 'package:flutter/material.dart';

/// Selector de fecha en forma de campo de texto (InkWell + InputDecorator),
/// usado para "Fecha de factura" y "Fecha de vencimiento" en
/// facturacion_screen.dart. Ambos campos eran idénticos (mismo formato
/// yyyy-MM-dd) salvo por qué fecha mostraban y a qué rango de fechas
/// válidas se limitaban — se unifican acá sin cambiar nada del original.
class FechaPickerField extends StatelessWidget {
  final DateTime fecha;
  final DateTime firstDate;
  final DateTime lastDate;
  final ValueChanged<DateTime> onFechaSeleccionada;

  const FechaPickerField({
    super.key,
    required this.fecha,
    required this.firstDate,
    required this.lastDate,
    required this.onFechaSeleccionada,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        final seleccionada = await showDatePicker(
          context: context,
          initialDate: fecha,
          firstDate: firstDate,
          lastDate: lastDate,
        );
        if (seleccionada != null) onFechaSeleccionada(seleccionada);
      },
      child: InputDecorator(
        decoration: InputDecoration(
          border: OutlineInputBorder(),
          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
          suffixIcon: Icon(
            Icons.calendar_today,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
            size: 18,
          ),
          filled: true,
          fillColor: Theme.of(context).colorScheme.surface,
        ),
        child: Text(
          '${fecha.year}-${fecha.month.toString().padLeft(2, '0')}-${fecha.day.toString().padLeft(2, '0')}',
          style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 14),
        ),
      ),
    );
  }
}
