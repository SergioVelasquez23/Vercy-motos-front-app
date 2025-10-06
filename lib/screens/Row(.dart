import 'package:flutter/material.dart';

// Definir colores como constantes
const Color textDark = Colors.black87;
const Color textLight = Colors.grey;

// Ejemplo de widget que usa el Row
class PedidoRowWidget extends StatelessWidget {
  final dynamic pedido; // Cambiar por el tipo real del pedido

  const PedidoRowWidget({Key? key, required this.pedido}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          flex: 1, // antes 2
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (pedido.cliente != null && pedido.cliente.isNotEmpty)
                Text(
                  pedido.cliente,
                  style: const TextStyle(
                    color: textDark,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              Text(
                'Mesa: ${pedido.mesa}',
                style: const TextStyle(color: textLight, fontSize: 9),
              ),
            ],
          ),
        ),
        // ...resto igual...
      ],
    );
  }
}
