import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class TemperaturePage extends StatelessWidget {
  const TemperaturePage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Not authenticated')),
      );
    }

    return Scaffold(
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('temperature_history')
            .orderBy('timestamp', descending: true)
            .limit(24)
            .snapshots(),
        builder: (context, snapshot) {
          double currentTemp = 36.8;
          List<FlSpot> spots = [
            const FlSpot(0, 36.5),
            const FlSpot(6, 36.7),
            const FlSpot(12, 36.8),
            const FlSpot(18, 37.1),
            const FlSpot(24, 36.5),
          ];
          List<double> heatmapDataToday = [36.5, 36.7, 36.8, 37.0, 36.9, 36.8, 36.7];
          List<double> heatmapDataYesterday = [36.7, 36.9, 37.1, 37.0, 36.9, 36.8, 36.7];

          if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
            final docs = snapshot.data!.docs;

            // Latest temp for gauge
            final latestDoc = docs.first.data() as Map<String, dynamic>;
            currentTemp = (latestDoc['value'] as num?)?.toDouble() ?? currentTemp;

            // Sort docs by timestamp ascending for graph representation
            final sortedDocs = docs.toList()
              ..sort((a, b) {
                final aTime = (a.data() as Map<String, dynamic>)['timestamp'] as Timestamp?;
                final bTime = (b.data() as Map<String, dynamic>)['timestamp'] as Timestamp?;
                if (aTime == null || bTime == null) return 0;
                return aTime.compareTo(bTime);
              });

            spots = [];
            for (var doc in sortedDocs) {
              final data = doc.data() as Map<String, dynamic>;
              final val = (data['value'] as num?)?.toDouble();
              final ts = data['timestamp'] as Timestamp?;
              if (val != null && ts != null) {
                final dt = ts.toDate();
                double xVal = dt.hour + (dt.minute / 60.0);
                spots.add(FlSpot(xVal, val));
              }
            }

            if (spots.isEmpty) {
              spots = [
                const FlSpot(0, 36.5),
                const FlSpot(6, 36.7),
                const FlSpot(12, 36.8),
                const FlSpot(18, 37.1),
                const FlSpot(24, 36.5),
              ];
            }

            // Fill heatmap
            final values = docs
                .map((d) => ((d.data() as Map<String, dynamic>)['value'] as num?)?.toDouble() ?? 36.8)
                .toList();
            for (int i = 0; i < 7; i++) {
              if (i < values.length) {
                heatmapDataToday[6 - i] = values[i];
              }
              if (i + 7 < values.length) {
                heatmapDataYesterday[6 - i] = values[i + 7];
              }
            }
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildTemperatureGauge(context, currentTemp),
                const SizedBox(height: 20),
                _buildTemperatureAreaChart(context, spots),
                const SizedBox(height: 20),
                _buildTemperatureHeatMap(context, heatmapDataToday, heatmapDataYesterday),
                const SizedBox(height: 20),
                _buildTemperatureStats(context, spots),
              ],
            ),
          );
        },
      ),
    );
  }

  /// =========================
  /// 🔵 TEMPERATURE GAUGE
  /// =========================
  Widget _buildTemperatureGauge(BuildContext context, double currentTemp) {
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
  Widget _buildTemperatureAreaChart(BuildContext context, List<FlSpot> spots) {
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
                  minY: 35.5,
                  maxY: 39.0,
                  borderData: FlBorderData(show: false),
                  gridData: const FlGridData(show: true),
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      barWidth: 3,
                      color: Colors.orange,
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
  Widget _buildTemperatureHeatMap(
      BuildContext context, List<double> today, List<double> yesterday) {
    final data = [yesterday, today];

    return Card(
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Temperature Heatmap (Yesterday vs Today)',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 15),
            Column(
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
                            temp.toStringAsFixed(1),
                            style: const TextStyle(
                              color: Colors.black87,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  /// =========================
  /// 📊 STATS
  /// =========================
  Widget _buildTemperatureStats(BuildContext context, List<FlSpot> spots) {
    double minTemp = 36.0;
    double maxTemp = 37.0;
    double avgTemp = 36.8;

    if (spots.isNotEmpty) {
      final values = spots.map((s) => s.y).toList();
      minTemp = values.reduce((a, b) => a < b ? a : b);
      maxTemp = values.reduce((a, b) => a > b ? a : b);
      avgTemp = values.reduce((a, b) => a + b) / values.length;
    }

    return Card(
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Temperature Statistics',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 15),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _statWidget('Min Temp', '${minTemp.toStringAsFixed(1)}°C', Colors.blue),
                _statWidget('Avg Temp', '${avgTemp.toStringAsFixed(1)}°C', Colors.green),
                _statWidget('Max Temp', '${maxTemp.toStringAsFixed(1)}°C', Colors.red),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _statWidget(String label, String value, Color color) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 5),
        Text(
          value,
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color),
        ),
      ],
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

    if (temp < 36.5) return Colors.blue.shade200.withOpacity(opacity);
    if (temp < 36.8) return Colors.green.shade200.withOpacity(opacity);
    if (temp < 37.0) return Colors.yellow.shade200.withOpacity(opacity);
    if (temp < 37.2) return Colors.orange.shade200.withOpacity(opacity);
    return Colors.red.shade200.withOpacity(opacity);
  }
}
