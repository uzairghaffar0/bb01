import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class TemperaturePage extends StatelessWidget {
  const TemperaturePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Temperature')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTemperatureGauge(context),
            const SizedBox(height: 20),
            _buildTemperatureAreaChart(context),
            const SizedBox(height: 20),
            _buildTemperatureHeatMap(context),
            const SizedBox(height: 20),
            _buildTemperatureStats(context),
          ],
        ),
      ),
    );
  }

  /// =========================
  /// 🔵 TEMPERATURE GAUGE
  /// =========================
  Widget _buildTemperatureGauge(BuildContext context) {
    double currentTemp = 36.8;

    return Card(
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Text(
              'Current Temperature',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 15),
            SizedBox(
              height: 180,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  /// Background ring
                  Container(
                    width: 180,
                    height: 180,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Theme.of(context).dividerColor,
                        width: 15,
                      ),
                    ),
                  ),

                  /// Gradient ring (fixed)
                  Container(
                    width: 180,
                    height: 180,
                    decoration: const BoxDecoration(shape: BoxShape.circle),
                    child: Padding(
                      padding: const EdgeInsets.all(15),
                      child: Container(
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: SweepGradient(
                            colors: [
                              Colors.blue,
                              Colors.green,
                              Colors.yellow,
                              Colors.orange,
                              Colors.red,
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  /// Inner circle
                  Container(
                    width: 140,
                    height: 140,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Theme.of(context).cardColor,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              currentTemp.toStringAsFixed(1),
                              style: const TextStyle(
                                fontSize: 42,
                                fontWeight: FontWeight.bold,
                                color: Colors.orange,
                              ),
                            ),
                            const SizedBox(width: 5),
                            const Text(
                              '°C',
                              style: TextStyle(
                                fontSize: 24,
                                color: Colors.orange,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 5),
                        Text(
                          _getTempStatus(currentTemp),
                          style: TextStyle(
                            fontSize: 16,
                            color: _getTempStatusColor(currentTemp),
                          ),
                        ),
                      ],
                    ),
                  ),

                ],
              ),
            ),
            const SizedBox(height: 15),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('35°C', style: TextStyle(color: Colors.blue[700])),
                Text('36°C', style: TextStyle(color: Colors.green[700])),
                Text('37°C', style: TextStyle(color: Colors.orange[700])),
                Text('38°C', style: TextStyle(color: Colors.red[700])),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// =========================
  /// 📈 AREA CHART
  /// =========================
  Widget _buildTemperatureAreaChart(BuildContext context) {
    final List<FlSpot> tempData = [
      const FlSpot(0, 36.5),
      const FlSpot(6, 36.7),
      const FlSpot(12, 36.8),
      const FlSpot(18, 37.1),
      const FlSpot(24, 36.5),
    ];

    return Card(
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('24-Hour Trend',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  minX: 0,
                  maxX: 24,
                  minY: 36,
                  maxY: 37.5,
                  borderData: FlBorderData(show: false),
                  gridData: FlGridData(show: true),
                  lineBarsData: [
                    LineChartBarData(
                      spots: tempData,
                      isCurved: true,
                      barWidth: 0,
                      belowBarData: BarAreaData(
                        show: true,
                        gradient: LinearGradient(
                          colors: [
                            Colors.orange.withOpacity(0.5),
                            Colors.orange.withOpacity(0.1),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// =========================
  /// 🔥 HEATMAP
  /// =========================
  Widget _buildTemperatureHeatMap(BuildContext context) {
    final data = [
      [36.5, 36.7, 36.8, 37.0, 36.9, 36.8, 36.7],
      [36.7, 36.9, 37.1, 37.0, 36.9, 36.8, 36.7],
    ];

    return Card(
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: List.generate(2, (i) {
            return Row(
              children: List.generate(7, (j) {
                double temp = data[i][j];
                return Expanded(
                  child: Container(
                    margin: const EdgeInsets.all(2),
                    height: 40,
                    decoration: BoxDecoration(
                      color: _getHeatMapColor(temp, context),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Center(
                        child: Text(
                      '${temp.toStringAsFixed(1)}',
                      style: const TextStyle(color: Colors.black87),
                    )),
                  ),
                );
              }),
            );
          }),
        ),
      ),
    );
  }

  /// =========================
  /// 📊 STATS
  /// =========================
  Widget _buildTemperatureStats(BuildContext context) {
    return Card(
      elevation: 3,
      child: const Padding(
        padding: EdgeInsets.all(16),
        child: Text('Temperature Stats'),
      ),
    );
  }

  /// =========================
  /// 🎯 HELPERS
  /// =========================
  Color _getTempStatusColor(double temp) {
    if (temp < 36.5) return Colors.blue;
    if (temp <= 37.0) return Colors.green;
    if (temp <= 37.5) return Colors.orange;
    return Colors.red;
  }

  String _getTempStatus(double temp) {
    if (temp < 36.5) return 'Low';
    if (temp <= 37.0) return 'Normal';
    if (temp <= 37.5) return 'High';
    return 'Very High';
  }

  Color _getHeatMapColor(double temp, BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    double opacity = isDark ? 0.7 : 1.0;
    
    if (temp < 36.5) return Colors.blue.shade200.withValues(alpha: opacity);
    if (temp < 36.8) return Colors.green.shade200.withValues(alpha: opacity);
    if (temp < 37.0) return Colors.yellow.shade200.withValues(alpha: opacity);
    if (temp < 37.2) return Colors.orange.shade200.withValues(alpha: opacity);
    return Colors.red.shade200.withValues(alpha: opacity);
  }
}
