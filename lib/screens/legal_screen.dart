import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../utils/legal_texts.dart';

/// Pantalla de consulta de los documentos legales de la Plataforma
/// (Términos y Condiciones, Política de Tratamiento de Datos Personales y
/// Aviso de Privacidad). Solo lectura: no captura ni registra aceptación —
/// esa autorización se recoge donde corresponda (registro de usuario,
/// creación de cliente, etc.), esta pantalla es la referencia consultable.
class LegalScreen extends StatefulWidget {
  const LegalScreen({super.key});

  @override
  State<LegalScreen> createState() => _LegalScreenState();
}

class _LegalScreenState extends State<LegalScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  static const _documentos = [
    (icon: Icons.description_outlined, titulo: 'Términos y Condiciones', texto: terminosYCondicionesTexto),
    (icon: Icons.shield_outlined, titulo: 'Tratamiento de Datos', texto: politicaTratamientoDatosTexto),
    (icon: Icons.privacy_tip_outlined, titulo: 'Aviso de Privacidad', texto: avisoPrivacidadTexto),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _documentos.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Legal y Privacidad'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: [
            for (final doc in _documentos)
              Tab(icon: Icon(doc.icon), text: doc.titulo),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          for (final doc in _documentos)
            SingleChildScrollView(
              padding: const EdgeInsets.all(AppTheme.spacingLarge),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: SelectableText(
                  doc.texto.trim(),
                  style: TextStyle(color: onSurface, fontSize: 13, height: 1.5),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
