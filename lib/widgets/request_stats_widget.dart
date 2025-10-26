import 'dart:async';
import 'package:flutter/material.dart';
import '../utils/request_monitor.dart';

class RequestStatsWidget extends StatefulWidget {
  const RequestStatsWidget({Key? key}) : super(key: key);

  @override
  State<RequestStatsWidget> createState() => _RequestStatsWidgetState();
}

class _RequestStatsWidgetState extends State<RequestStatsWidget> {
  final RequestMonitor _monitor = RequestMonitor();
  late RequestStats _stats;

  @override
  void initState() {
    super.initState();
    _updateStats();
    // Actualizar stats cada 30 segundos
    Timer.periodic(Duration(seconds: 30), (timer) {
      if (mounted) {
        _updateStats();
      }
    });
  }

  void _updateStats() {
    setState(() {
      _stats = _monitor.getStats();
    });
  }

  @override
  Widget build(BuildContext context) {
    final usagePercent = (_stats.projectedMonthly / 125000 * 100);
    final isNearLimit = usagePercent > 80;

    return Container(
      margin: EdgeInsets.all(8),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isNearLimit ? Colors.orange.shade50 : Colors.blue.shade50,
        border: Border.all(
          color: isNearLimit ? Colors.orange : Colors.blue,
          width: 1,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(
                Icons.analytics,
                size: 16,
                color: isNearLimit ? Colors.orange : Colors.blue,
              ),
              SizedBox(width: 8),
              Text(
                'Uso de API',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isNearLimit
                      ? Colors.orange.shade800
                      : Colors.blue.shade800,
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          _buildStatRow('Hoy:', '${_stats.totalToday} requests'),
          _buildStatRow('Por hora:', '${_stats.averagePerHour} requests'),
          _buildStatRow(
            'Proyección diaria:',
            '${_stats.projectedDaily} requests',
          ),
          _buildStatRow(
            'Proyección mensual:',
            '${_stats.projectedMonthly} requests',
          ),
          SizedBox(height: 4),
          _buildProgressBar(usagePercent, isNearLimit),
          SizedBox(height: 4),
          Text(
            'Netlify: ${usagePercent.toStringAsFixed(1)}% usado',
            style: TextStyle(
              fontSize: 12,
              color: isNearLimit
                  ? Colors.orange.shade700
                  : Colors.blue.shade700,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.only(bottom: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
          Text(
            value,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBar(double percent, bool isNearLimit) {
    return Container(
      height: 4,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(2),
        color: Colors.grey.shade300,
      ),
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: (percent / 100).clamp(0.0, 1.0),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(2),
            color: isNearLimit ? Colors.orange : Colors.blue,
          ),
        ),
      ),
    );
  }
}
