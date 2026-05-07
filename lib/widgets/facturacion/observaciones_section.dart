import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class ObservacionesSection extends StatelessWidget {
  final TextEditingController observacionesController;

  const ObservacionesSection({
    super.key,
    required this.observacionesController,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.note_alt, color: AppTheme.primary, size: 24),
              SizedBox(width: 12),
              Text(
                'Observaciones',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          TextField(
            controller: observacionesController,
            maxLines: 3,
            style: TextStyle(color: AppTheme.textPrimary, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Ej: Abonado \$50,000 - Paquete 1, etc...',
              hintStyle: TextStyle(color: AppTheme.textSecondary),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              contentPadding: EdgeInsets.all(16),
              filled: true,
              fillColor: AppTheme.surfaceDark,
            ),
          ),
        ],
      ),
    );
  }
}
