import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/documento_mesa.dart';
import '../models/factura_electronica_dian.dart';
import '../config/factura_electronica_config.dart';
import '../services/factura_electronica_service.dart';
import '../services/configuracion_facturacion_service.dart';

/// Diálogo para capturar información del cliente para factura electrónica
///
/// Uso:
/// ```dart
/// final resultado = await showDialog<Map<String, dynamic>>(
///   context: context,
///   builder: (context) => DatosFacturaElectronicaDialog(
///     documentoMesa: documento,
///   ),
/// );
///
/// if (resultado != null) {
///   // Usuario proporcionó datos para factura
///   final documentoConDatos = documento.copyWith(
///     requiereFacturaElectronica: true,
///     clienteNombre: resultado['nombre'],
///     clienteIdentificacion: resultado['identificacion'],
///     clienteTipoDocumento: resultado['tipoDocumento'],
///     clienteEmail: resultado['email'],
///     clienteTelefono: resultado['telefono'],
///     clienteDireccion: resultado['direccion'],
///   );
/// }
/// ```
class DatosFacturaElectronicaDialog extends StatefulWidget {
  final DocumentoMesa documentoMesa;

  const DatosFacturaElectronicaDialog({Key? key, required this.documentoMesa})
    : super(key: key);

  @override
  State<DatosFacturaElectronicaDialog> createState() =>
      _DatosFacturaElectronicaDialogState();
}

class _DatosFacturaElectronicaDialogState
    extends State<DatosFacturaElectronicaDialog> {
  final _formKey = GlobalKey<FormState>();

  final _nombreController = TextEditingController();
  final _identificacionController = TextEditingController();
  final _emailController = TextEditingController();
  final _telefonoController = TextEditingController();
  final _direccionController = TextEditingController();

  String _tipoDocumento = '13'; // Cédula por defecto
  bool _esConsumidorFinal = false;

  @override
  void initState() {
    super.initState();

    // Pre-llenar con datos existentes si los hay
    if (widget.documentoMesa.clienteNombre != null) {
      _nombreController.text = widget.documentoMesa.clienteNombre!;
    }
    if (widget.documentoMesa.clienteIdentificacion != null) {
      _identificacionController.text =
          widget.documentoMesa.clienteIdentificacion!;
    }
    if (widget.documentoMesa.clienteTipoDocumento != null) {
      _tipoDocumento = widget.documentoMesa.clienteTipoDocumento!;
    }
    if (widget.documentoMesa.clienteEmail != null) {
      _emailController.text = widget.documentoMesa.clienteEmail!;
    }
    if (widget.documentoMesa.clienteTelefono != null) {
      _telefonoController.text = widget.documentoMesa.clienteTelefono!;
    }
    if (widget.documentoMesa.clienteDireccion != null) {
      _direccionController.text = widget.documentoMesa.clienteDireccion!;
    }
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _identificacionController.dispose();
    _emailController.dispose();
    _telefonoController.dispose();
    _direccionController.dispose();
    super.dispose();
  }

  void _onConsumidorFinalChanged(bool? value) {
    setState(() {
      _esConsumidorFinal = value ?? false;

      if (_esConsumidorFinal) {
        _nombreController.text = 'CONSUMIDOR FINAL';
        _identificacionController.text = '222222222222';
        _tipoDocumento = '13';
      } else {
        _nombreController.clear();
        _identificacionController.clear();
      }
    });
  }

  void _onGuardar() {
    if (_formKey.currentState!.validate()) {
      Navigator.of(context).pop({
        'nombre': _nombreController.text,
        'identificacion': _identificacionController.text,
        'tipoDocumento': _tipoDocumento,
        'email': _emailController.text.isEmpty ? null : _emailController.text,
        'telefono': _telefonoController.text.isEmpty
            ? null
            : _telefonoController.text,
        'direccion': _direccionController.text.isEmpty
            ? null
            : _direccionController.text,
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.receipt_long, color: Theme.of(context).primaryColor),
          const SizedBox(width: 8),
          const Text('Datos para Factura Electrónica'),
        ],
      ),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Información del documento
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Mesa: ${widget.documentoMesa.mesaNombre}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Total: \$${widget.documentoMesa.total.toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Checkbox para consumidor final
              CheckboxListTile(
                title: const Text('Consumidor Final'),
                subtitle: const Text('Sin identificación específica'),
                value: _esConsumidorFinal,
                onChanged: _onConsumidorFinalChanged,
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
              ),

              const Divider(),

              // Tipo de documento
              DropdownButtonFormField<String>(
                value: _tipoDocumento,
                decoration: const InputDecoration(
                  labelText: 'Tipo de Documento *',
                  prefixIcon: Icon(Icons.assignment_ind),
                ),
                items: FacturaElectronicaConfig.tiposDocumento.entries
                    .map(
                      (entry) => DropdownMenuItem(
                        value: entry.key,
                        child: Text('${entry.value} (${entry.key})'),
                      ),
                    )
                    .toList(),
                onChanged: _esConsumidorFinal
                    ? null
                    : (value) => setState(() => _tipoDocumento = value!),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Seleccione un tipo de documento';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 16),

              // Número de identificación
              TextFormField(
                controller: _identificacionController,
                decoration: const InputDecoration(
                  labelText: 'Número de Identificación *',
                  prefixIcon: Icon(Icons.badge),
                  helperText: 'CC, NIT o documento',
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                enabled: !_esConsumidorFinal,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Ingrese el número de identificación';
                  }
                  if (value.length < 5) {
                    return 'Identificación inválida';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 16),

              // Nombre o razón social
              TextFormField(
                controller: _nombreController,
                decoration: const InputDecoration(
                  labelText: 'Nombre o Razón Social *',
                  prefixIcon: Icon(Icons.person),
                ),
                textCapitalization: TextCapitalization.words,
                enabled: !_esConsumidorFinal,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Ingrese el nombre';
                  }
                  if (value.length < 3) {
                    return 'Nombre demasiado corto';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 16),

              // Email (opcional pero recomendado)
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Email (Recomendado)',
                  prefixIcon: Icon(Icons.email),
                  helperText: 'Para enviar copia de la factura',
                ),
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value != null && value.isNotEmpty) {
                    final emailRegex = RegExp(
                      r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                    );
                    if (!emailRegex.hasMatch(value)) {
                      return 'Email inválido';
                    }
                  }
                  return null;
                },
              ),

              const SizedBox(height: 16),

              // Teléfono (opcional)
              TextFormField(
                controller: _telefonoController,
                decoration: const InputDecoration(
                  labelText: 'Teléfono (Opcional)',
                  prefixIcon: Icon(Icons.phone),
                ),
                keyboardType: TextInputType.phone,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(10),
                ],
              ),

              const SizedBox(height: 16),

              // Dirección (opcional)
              TextFormField(
                controller: _direccionController,
                decoration: const InputDecoration(
                  labelText: 'Dirección (Opcional)',
                  prefixIcon: Icon(Icons.location_on),
                ),
                textCapitalization: TextCapitalization.words,
                maxLines: 2,
              ),

              const SizedBox(height: 16),

              // Nota informativa
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber.shade200),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Colors.amber.shade700,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'La factura electrónica será generada y enviada a la DIAN. '
                        'Si proporciona un email, recibirá una copia.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.amber.shade900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        ElevatedButton.icon(
          onPressed: _onGuardar,
          icon: const Icon(Icons.check),
          label: const Text('Generar Factura'),
        ),
      ],
    );
  }
}

/// Widget para mostrar el estado de una factura electrónica
class EstadoFacturaElectronicaWidget extends StatelessWidget {
  final DocumentoMesa documentoMesa;

  const EstadoFacturaElectronicaWidget({Key? key, required this.documentoMesa})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (!documentoMesa.requiereFacturaElectronica) {
      return const SizedBox.shrink();
    }

    final estado = documentoMesa.estadoFacturaElectronica ?? 'PENDIENTE';
    Color colorEstado;
    IconData iconoEstado;

    switch (estado) {
      case 'EMITIDA':
      case 'ENVIADA_DIAN':
        colorEstado = Colors.blue;
        iconoEstado = Icons.send;
        break;
      case 'ACEPTADA':
        colorEstado = Colors.green;
        iconoEstado = Icons.check_circle;
        break;
      case 'RECHAZADA':
        colorEstado = Colors.red;
        iconoEstado = Icons.error;
        break;
      default:
        colorEstado = Colors.orange;
        iconoEstado = Icons.pending;
    }

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: colorEstado.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colorEstado),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(iconoEstado, color: colorEstado, size: 20),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Factura Electrónica',
                style: TextStyle(
                  fontSize: 12,
                  color: colorEstado,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (documentoMesa.facturaElectronica != null)
                Text(
                  documentoMesa.facturaElectronica!.numeroFactura,
                  style: TextStyle(fontSize: 11, color: colorEstado),
                ),
              Text(estado, style: TextStyle(fontSize: 10, color: colorEstado)),
            ],
          ),
        ],
      ),
    );
  }
}

/// Botón para solicitar factura electrónica
class BotonSolicitarFacturaElectronica extends StatefulWidget {
  final DocumentoMesa documentoMesa;
  final Function(DocumentoMesa, dynamic)? onFacturaGenerada;
  final bool compact;

  const BotonSolicitarFacturaElectronica({
    Key? key,
    required this.documentoMesa,
    this.onFacturaGenerada,
    this.compact = false,
  }) : super(key: key);

  @override
  State<BotonSolicitarFacturaElectronica> createState() =>
      _BotonSolicitarFacturaElectronicaState();
}

class _BotonSolicitarFacturaElectronicaState
    extends State<BotonSolicitarFacturaElectronica> {
  bool _generando = false;

  /// Convierte FacturaElectronicaDian al formato esperado por el backend
  Map<String, dynamic> _convertirFacturaParaBackend(
    FacturaElectronicaDian factura,
    DocumentoMesa documento,
  ) {
    // Extraer prefijo y consecutivo del numeroFactura
    final numeroCompleto = factura.numeroFactura;
    final prefijo = factura.prefijoFactura ?? '';
    final consecutivoStr = numeroCompleto.replaceAll(prefijo, '');
    final consecutivo = int.tryParse(consecutivoStr) ?? 0;

    return {
      'numeroFactura': factura.numeroFactura,
      'prefijo': prefijo,
      'consecutivo': consecutivo,
      'fechaEmision': factura.fechaEmision.toIso8601String(),
      'horaEmision': factura.horaEmision,
      'nitEmisor': factura.emisor.nit,
      'nombreEmisor': factura.emisor.razonSocial,
      'nitCliente': factura.adquiriente.identificacion,
      'nombreCliente': factura.adquiriente.nombre,
      'emailCliente': factura.adquiriente.email ?? '',
      'telefonoCliente': factura.adquiriente.telefono ?? '',
      'direccionCliente': factura.adquiriente.direccion,
      'items': factura.items.asMap().entries.map((entry) {
        final index = entry.key;
        final item = entry.value;
        return {
          'numero': index + 1,
          'codigo': item.codigoProducto,
          'descripcion': item.descripcion,
          'cantidad': item.cantidad,
          'unidadMedida': item.unidadMedida,
          'valorUnitario': item.precioUnitario,
          'valorTotal': item.totalItem,
          'porcentajeIva': item.impuestos.isNotEmpty
              ? item.impuestos[0].porcentaje
              : 0,
          'valorIva': item.impuestos.isNotEmpty ? item.impuestos[0].valorImpuesto : 0,
          'descuento': item.descuento ?? 0,
        };
      }).toList(),
      'subtotal': factura.subtotal,
      'totalIva': factura.totalImpuestos,
      'totalDescuentos': factura.totalDescuentos,
      'totalPropina': factura.propina ?? 0,
      'total': factura.totalFactura,
      'cufe': factura.cufe ?? '',
      'xmlFactura': factura.xmlGenerado ?? '',
      'qrCode': factura.qrCode ?? '',
      'estado': 'generada',
      'documentoMesaId': documento.id,
      'pedidosIds': documento.pedidosIds,
      'creadoPor': 'Sistema',
    };
  }

  Future<void> _solicitarFactura() async {
    // Capturar datos del cliente
    final resultado = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) =>
          DatosFacturaElectronicaDialog(documentoMesa: widget.documentoMesa),
    );

    if (resultado == null) return;

    setState(() => _generando = true);

    try {
      // Actualizar documento con datos del cliente
      final documentoActualizado = widget.documentoMesa.copyWith(
        requiereFacturaElectronica: true,
        clienteNombre: resultado['nombre'],
        clienteIdentificacion: resultado['identificacion'],
        clienteTipoDocumento: resultado['tipoDocumento'],
        clienteEmail: resultado['email'],
        clienteTelefono: resultado['telefono'],
        clienteDireccion: resultado['direccion'],
      );

      // Obtener siguiente consecutivo
      final configuracionService = ConfiguracionFacturacionService();
      final consecutivo = await configuracionService
          .obtenerSiguienteConsecutivo();

      if (consecutivo == null) {
        throw Exception(
          'No se pudo obtener el consecutivo. Verifica la configuración.',
        );
      }

      // Generar factura electrónica
      final factura =
          await FacturaElectronicaService.generarFacturaDesdeDocumentoMesa(
            documentoMesa: documentoActualizado,
            numeroConsecutivo: consecutivo,
            clienteNombre: resultado['nombre'],
            clienteIdentificacion: resultado['identificacion'],
            clienteTipoDocumento: resultado['tipoDocumento'],
            clienteEmail: resultado['email'],
            clienteTelefono: resultado['telefono'],
            clienteDireccion: resultado['direccion'],
          );

      // Guardar factura en el backend
      final facturaGuardada = await configuracionService.guardarFactura(
        _convertirFacturaParaBackend(factura, documentoActualizado),
      );

      if (facturaGuardada == null) {
        throw Exception('Error al guardar la factura en el servidor');
      }

      // Incrementar consecutivo después de guardar exitosamente
      await configuracionService.incrementarConsecutivo();

      // Llamar callback si existe
      if (widget.onFacturaGenerada != null) {
        widget.onFacturaGenerada!(documentoActualizado, factura);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '✅ Factura ${factura.numeroFactura} generada exitosamente',
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error al generar factura: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _generando = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.compact) {
      return ElevatedButton.icon(
        onPressed: _generando ? null : _solicitarFactura,
        icon: _generando
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.receipt_long, size: 16),
        label: Text('Factura', style: const TextStyle(fontSize: 12)),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue.withOpacity(0.2),
          foregroundColor: Colors.blue,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ),
      );
    }

    return ElevatedButton.icon(
      onPressed: _generando ? null : _solicitarFactura,
      icon: _generando
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.receipt_long),
      label: const Text('Solicitar Factura Electrónica'),
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      ),
    );
  }
}
