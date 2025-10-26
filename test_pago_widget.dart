import 'package:flutter/material.dart';

void main() {
  runApp(const TestApp());
}

class TestApp extends StatelessWidget {
  const TestApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(title: 'Test Pago Dialog', home: const TestPagoScreen());
  }
}

class TestPagoScreen extends StatefulWidget {
  const TestPagoScreen({Key? key}) : super(key: key);

  @override
  State<TestPagoScreen> createState() => _TestPagoScreenState();
}

class _TestPagoScreenState extends State<TestPagoScreen> {
  String medioPago0 = 'efectivo';
  final Color _primary = const Color(0xFFFF6B35);
  final Color _textMuted = Colors.grey;
  final Color _textSecondary = Colors.grey.shade400;
  final Color _cardBg = const Color(0xFF2C2C2E);

  Widget _buildSeccionTitulo(String titulo) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 12, horizontal: 18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_primary.withOpacity(0.15), _primary.withOpacity(0.05)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _primary.withOpacity(0.3), width: 1),
      ),
      child: Text(
        titulo,
        style: TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1C1C1E),
      appBar: AppBar(
        title: const Text('Test Pago Dialog'),
        backgroundColor: _primary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildSeccionTitulo('Método de Pago'),
            SizedBox(height: 16),
            Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: _cardBg.withOpacity(0.3),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _primary.withOpacity(0.2)),
              ),
              child: Column(
                children: [
                  // Botones de método de pago mejorados
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => medioPago0 = 'efectivo'),
                          child: Container(
                            padding: EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: medioPago0 == 'efectivo'
                                  ? _primary.withOpacity(0.2)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: medioPago0 == 'efectivo'
                                    ? _primary
                                    : _textMuted,
                                width: 2,
                              ),
                            ),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.money,
                                  color: medioPago0 == 'efectivo'
                                      ? _primary
                                      : _textSecondary,
                                  size: 24,
                                ),
                                SizedBox(height: 8),
                                Text(
                                  'Efectivo',
                                  style: TextStyle(
                                    color: medioPago0 == 'efectivo'
                                        ? _primary
                                        : _textSecondary,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: GestureDetector(
                          onTap: () =>
                              setState(() => medioPago0 = 'transferencia'),
                          child: Container(
                            padding: EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: medioPago0 == 'transferencia'
                                  ? _primary.withOpacity(0.2)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: medioPago0 == 'transferencia'
                                    ? _primary
                                    : _textMuted,
                                width: 2,
                              ),
                            ),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.credit_card,
                                  color: medioPago0 == 'transferencia'
                                      ? _primary
                                      : _textSecondary,
                                  size: 24,
                                ),
                                SizedBox(height: 8),
                                Text(
                                  'Tarjeta/Transfer.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: medioPago0 == 'transferencia'
                                        ? _primary
                                        : _textSecondary,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            SizedBox(height: 20),
            Text(
              'Método seleccionado: $medioPago0',
              style: TextStyle(color: Colors.white, fontSize: 18),
            ),
          ],
        ),
      ),
    );
  }
}
