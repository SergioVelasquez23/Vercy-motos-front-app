import 'package:flutter/material.dart';

// NOTE: Este archivo es un ejemplo no usado en runtime. Mantener compilable.

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
              Text(
                'ID: ${pedido.id}',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'Mesa: ${pedido.mesa}',
                style: TextStyle(color: Colors.grey, fontSize: 9),
              ),
            ],
          ),
        ),
        // ...resto igual...
      ],
    );
  }
}
