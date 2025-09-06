import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class ResponsiveOrdersChart extends StatelessWidget {
  final List<Map<String, dynamic>> pedidosPorHora;
  final Color primaryColor;
  final Color textColor;
  final Color backgroundColor;
  final String selectedPeriod;
  final Function(String) onPeriodChanged;

  const ResponsiveOrdersChart({
    super.key,
    required this.pedidosPorHora,
    required this.primaryColor,
    required this.textColor,
    required this.backgroundColor,
    required this.selectedPeriod,
    required this.onPeriodChanged,
  });

  double _getMaxPedidosHora() {
    if (pedidosPorHora.isEmpty) return 10;
    return pedidosPorHora
        .map((data) => (data['cantidad'] as num).toDouble())
        .reduce((a, b) => a > b ? a : b)
        .toDouble();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.circle, color: primaryColor, size: 12),
                  SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      'CANTIDAD PEDIDOS POR HORA',
                      style: TextStyle(
                        color: textColor,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              LayoutBuilder(
                builder: (context, constraints) {
                  // En móviles muy pequeños, ocultar el dropdown
                  if (constraints.maxWidth < 200) {
                    return SizedBox.shrink();
                  }

                  return Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.grey.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: DropdownButton<String>(
                      value: selectedPeriod,
                      underline: Container(),
                      dropdownColor: backgroundColor,
                      style: TextStyle(color: textColor, fontSize: 11),
                      items: ['12 horas', '24 horas', '7 días'].map((
                        String value,
                      ) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(value),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        if (newValue != null) {
                          onPeriodChanged(newValue);
                        }
                      },
                    ),
                  );
                },
              ),
            ],
          ),
          SizedBox(height: 20),

          // Chart responsivo
          LayoutBuilder(
            builder: (context, constraints) {
              bool isMobile = constraints.maxWidth < 400;
              bool isSmallMobile = constraints.maxWidth < 300;

              double chartHeight = isSmallMobile ? 150 : (isMobile ? 180 : 200);
              double fontSize = isSmallMobile ? 8 : (isMobile ? 9 : 10);
              double reservedBottomSize = isSmallMobile
                  ? 25
                  : (isMobile ? 30 : 35);
              double reservedLeftSize = isSmallMobile
                  ? 30
                  : (isMobile ? 35 : 45);

              return SizedBox(
                height: chartHeight,
                child: pedidosPorHora.isEmpty
                    ? Center(
                        child: CircularProgressIndicator(color: primaryColor),
                      )
                    : LineChart(
                        LineChartData(
                          gridData: FlGridData(
                            show: true,
                            drawVerticalLine: false,
                            getDrawingHorizontalLine: (value) {
                              return FlLine(
                                color: Colors.grey.withOpacity(0.2),
                                strokeWidth: 1,
                              );
                            },
                          ),
                          titlesData: FlTitlesData(
                            show: true,
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: reservedBottomSize,
                                interval: _getBottomInterval(
                                  isMobile,
                                  isSmallMobile,
                                ),
                                getTitlesWidget: (value, meta) {
                                  if (value.toInt() >= 0 &&
                                      value.toInt() < pedidosPorHora.length) {
                                    final hora =
                                        pedidosPorHora[value.toInt()]['hora'];
                                    return Padding(
                                      padding: EdgeInsets.only(top: 8),
                                      child: Text(
                                        hora,
                                        style: TextStyle(
                                          color: textColor.withOpacity(0.7),
                                          fontSize: fontSize,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    );
                                  }
                                  return Text('');
                                },
                              ),
                            ),
                            leftTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: reservedLeftSize,
                                interval: _getLeftInterval(
                                  isMobile,
                                  isSmallMobile,
                                ),
                                getTitlesWidget: (value, meta) {
                                  return Text(
                                    value.toInt().toString(),
                                    style: TextStyle(
                                      color: textColor.withOpacity(0.7),
                                      fontSize: fontSize,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  );
                                },
                              ),
                            ),
                            topTitles: AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                            rightTitles: AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                          ),
                          borderData: FlBorderData(
                            show: true,
                            border: Border(
                              bottom: BorderSide(
                                color: Colors.grey.withOpacity(0.2),
                                width: 1,
                              ),
                              left: BorderSide(
                                color: Colors.grey.withOpacity(0.2),
                                width: 1,
                              ),
                            ),
                          ),
                          minX: 0,
                          maxX: (pedidosPorHora.length - 1).toDouble(),
                          minY: 0,
                          maxY: _getMaxPedidosHora() * 1.2,
                          lineBarsData: [
                            LineChartBarData(
                              spots: pedidosPorHora.asMap().entries.map((
                                entry,
                              ) {
                                return FlSpot(
                                  entry.key.toDouble(),
                                  entry.value['cantidad'].toDouble(),
                                );
                              }).toList(),
                              isCurved: true,
                              curveSmoothness: 0.3,
                              color: primaryColor,
                              barWidth: isSmallMobile ? 2 : 3,
                              belowBarData: BarAreaData(
                                show: true,
                                color: primaryColor.withOpacity(0.1),
                              ),
                              dotData: FlDotData(
                                show: true,
                                getDotPainter: (spot, percent, barData, index) {
                                  return FlDotCirclePainter(
                                    radius: isSmallMobile ? 3 : 4,
                                    color: primaryColor,
                                    strokeWidth: 2,
                                    strokeColor: Colors.white,
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
              );
            },
          ),
        ],
      ),
    );
  }

  double _getBottomInterval(bool isMobile, bool isSmallMobile) {
    if (isSmallMobile && pedidosPorHora.length > 6) return 4;
    if (isMobile && pedidosPorHora.length > 8) return 3;
    if (isMobile && pedidosPorHora.length > 6) return 2;
    if (pedidosPorHora.length > 12) return 2;
    return 1;
  }

  double _getLeftInterval(bool isMobile, bool isSmallMobile) {
    double maxY = _getMaxPedidosHora();
    if (maxY <= 0) return 1;

    if (isSmallMobile) return maxY / 2;
    if (isMobile) return maxY / 3;
    return maxY / 4;
  }
}
