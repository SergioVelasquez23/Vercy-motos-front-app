Row(
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
              color: textDark,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            'Mesa: ${pedido.mesa}',
            style: TextStyle(color: textLight, fontSize: 9),
          ),
        ],
      ),
    ),
    // ...resto igual...
  ],
),