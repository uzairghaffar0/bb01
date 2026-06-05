import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class HeartbeatPage extends StatelessWidget {
  const HeartbeatPage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(
        body: Center(child: Text("Not authenticated")),
      );
    }

    return Scaffold(
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('heartrate_history')
            .orderBy('timestamp', descending: true)
            .limit(50)
            .snapshots(),
        builder: (context, snapshot) {
          int latestHeartRate = 120;
          List<int> allHeartRates = [120, 125, 128, 130, 125, 132, 128, 130, 125, 120];
          List<Timestamp> allTimestamps = [];

          if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
            final docs = snapshot.data!.docs;
            final latestDoc = docs.first.data() as Map<String, dynamic>;
            latestHeartRate = (latestDoc['value'] as num?)?.toInt() ?? latestHeartRate;

            allHeartRates = [];
            for (var doc in docs) {
              final data = doc.data() as Map<String, dynamic>;
              final val = (data['value'] as num?)?.toInt();
              final ts = data['timestamp'] as Timestamp?;
              if (val != null && ts != null) {
                allHeartRates.add(val);
                allTimestamps.add(ts);
              }
            }

            if (allHeartRates.isEmpty) {
              allHeartRates = [120, 125, 128, 130, 125, 132, 128, 130, 125, 120];
            }
          }

          // Compute Statistics
          int minHR = allHeartRates.reduce((a, b) => a < b ? a : b);
          int maxHR = allHeartRates.reduce((a, b) => a > b ? a : b);
          int avgHR = (allHeartRates.reduce((a, b) => a + b) / allHeartRates.length).round();

          // Calculate Zones
          int normalCount = 0;
          int elevatedCount = 0;
          int highCount = 0;
          for (var hr in allHeartRates) {
            if (hr < 110) {
              normalCount++; // fallback
            } else if (hr <= 140) {
              normalCount++;
            } else if (hr <= 150) {
              elevatedCount++;
            } else {
              highCount++;
            }
          }
          double total = allHeartRates.length.toDouble();
          double normalPct = total > 0 ? (normalCount / total) * 100 : 70;
          double elevatedPct = total > 0 ? (elevatedCount / total) * 100 : 20;
          double highPct = total > 0 ? (highCount / total) * 100 : 10;

          // Split into time of day
          List<int> morningHRs = [];
          List<int> afternoonHRs = [];
          List<int> eveningHRs = [];
          List<int> nightHRs = [];

          for (int i = 0; i < allHeartRates.length; i++) {
            if (i < allTimestamps.length) {
              final hour = allTimestamps[i].toDate().hour;
              final hr = allHeartRates[i];
              if (hour >= 6 && hour < 12) {
                morningHRs.add(hr);
              } else if (hour >= 12 && hour < 18) {
                afternoonHRs.add(hr);
              } else if (hour >= 18 && hour < 24) {
                eveningHRs.add(hr);
              } else {
                nightHRs.add(hr);
              }
            }
          }

          // Fallbacks for Sparklines
          if (morningHRs.isEmpty) morningHRs = [120, 125, 128, 122];
          if (afternoonHRs.isEmpty) afternoonHRs = [130, 135, 132, 130];
          if (eveningHRs.isEmpty) eveningHRs = [125, 128, 130, 128];
          if (nightHRs.isEmpty) nightHRs = [120, 118, 115, 120];

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeartRateLive(context, latestHeartRate, allHeartRates),
                const SizedBox(height: 20),
                _buildSparklineCharts(context, morningHRs, afternoonHRs, eveningHRs, nightHRs),
                const SizedBox(height: 20),
                _buildHeartRateDistribution(context, allHeartRates),
                const SizedBox(height: 20),
                _buildHeartRateZones(context, normalPct, elevatedPct, highPct),
                const SizedBox(height: 20),
                _buildDetailedStats(context, minHR, maxHR, avgHR),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeartRateLive(BuildContext context, int latestHeartRate, List<int> heartRates) {
    String status = 'Normal';
    Color statusColor = Colors.green;
    if (latestHeartRate < 110) {
      status = 'Low';
      statusColor = Colors.blue;
    } else if (latestHeartRate > 150) {
      status = 'High';
      statusColor = Colors.red;
    } else if (latestHeartRate > 140) {
      status = 'Elevated';
      statusColor = Colors.orange;
    }

    final spots = List.generate(
      heartRates.length > 10 ? 10 : heartRates.length,
      (index) {
        int hr = heartRates[heartRates.length - 1 - index];
        return FlSpot(index.toDouble(), hr.toDouble());
      },
    );

    return Card(
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(Icons.favorite, color: Colors.red, size: 24),
                SizedBox(width: 8),
                Text(
                  'Live Heart Rate',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 15),

            Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 180,
                  height: 180,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.red.withOpacity(0.05),
                  ),
                  child: Center(
                    child: Container(
                      width: 150,
                      height: 150,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.red.withOpacity(0.1),
                      ),
                      child: Center(
                        child: Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.red.withOpacity(0.15),
                          ),
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.baseline,
                                  textBaseline: TextBaseline.alphabetic,
                                  children: [
                                    Text(
                                      '$latestHeartRate',
                                      style: const TextStyle(
                                        fontSize: 32,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.red,
                                      ),
                                    ),
                                    const SizedBox(width: 5),
                                    const Text(
                                      'BPM',
                                      style: TextStyle(fontSize: 14, color: Colors.red),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  status,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: statusColor,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 15),

            SizedBox(
              height: 40,
              child: LineChart(
                LineChartData(
                  gridData: const FlGridData(show: false),
                  titlesData: const FlTitlesData(show: false),
                  borderData: FlBorderData(show: false),
                  minX: 0,
                  maxX: (spots.length - 1).toDouble(),
                  minY: 90,
                  maxY: 170,
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      color: Colors.red,
                      barWidth: 2.5,
                      dotData: const FlDotData(show: false),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Last readings trend',
              style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSparklineCharts(
      BuildContext context, List<int> morning, List<int> afternoon, List<int> evening, List<int> night) {
    return Card(
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Heart Rate Patterns',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildMiniSparkline('Morning', morning, Colors.blue),
                _buildMiniSparkline('Afternoon', afternoon, Colors.orange),
                _buildMiniSparkline('Evening', evening, Colors.purple),
                _buildMiniSparkline('Night', night, Colors.indigo),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniSparkline(String label, List<int> data, Color color) {
    return Column(
      children: [
        SizedBox(
          width: 70,
          height: 40,
          child: LineChart(
            LineChartData(
              gridData: const FlGridData(show: false),
              titlesData: const FlTitlesData(show: false),
              borderData: FlBorderData(show: false),
              minX: 0,
              maxX: data.length.toDouble() - 1,
              minY: (data.reduce((a, b) => a < b ? a : b) - 5).toDouble(),
              maxY: (data.reduce((a, b) => a > b ? a : b) + 5).toDouble(),
              lineBarsData: [
                LineChartBarData(
                  spots: List.generate(
                      data.length,
                      (index) => FlSpot(index.toDouble(), data[index].toDouble())),
                  isCurved: true,
                  color: color,
                  barWidth: 1.5,
                  dotData: const FlDotData(show: false),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 5),
        Text(label, style: const TextStyle(fontSize: 12)),
        Text(
          '${data.last} BPM',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color),
        ),
      ],
    );
  }

  Widget _buildHeartRateDistribution(BuildContext context, List<int> heartRates) {
    final Map<int, int> frequency = {};
    for (var hr in heartRates) {
      int rounded = (hr ~/ 10) * 10;
      frequency[rounded] = (frequency[rounded] ?? 0) + 1;
    }

    final List<BarChartGroupData> barGroups = [];
    final keys = frequency.keys.toList()..sort();
    
    for (int i = 0; i < keys.length; i++) {
      int hrValue = keys[i];
      int count = frequency[hrValue]!;
      barGroups.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: count.toDouble(),
              color: _getHRColor(hrValue.toDouble()),
              width: 16,
              borderRadius: BorderRadius.circular(3),
            ),
          ],
        ),
      );
    }

    if (barGroups.isEmpty) {
      barGroups.add(BarChartGroupData(x: 0, barRods: [BarChartRodData(toY: 1, color: Colors.green, width: 16)]));
    }

    return Card(
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Heart Rate Distribution',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 150,
              child: BarChart(
                BarChartData(
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          int idx = value.toInt();
                          if (idx >= 0 && idx < keys.length) {
                            return Padding(
                              padding: const EdgeInsets.only(top: 4.0),
                              child: Text('${keys[idx]}', style: const TextStyle(fontSize: 10)),
                            );
                          }
                          return const SizedBox();
                        },
                        reservedSize: 20,
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          return Text(value.toInt().toString(), style: const TextStyle(fontSize: 10));
                        },
                        reservedSize: 20,
                      ),
                    ),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(
                    show: true,
                    border: Border.all(color: Theme.of(context).dividerColor),
                  ),
                  barGroups: barGroups,
                  gridData: const FlGridData(show: true),
                  alignment: BarChartAlignment.spaceAround,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeartRateZones(BuildContext context, double normal, double elevated, double high) {
    final List<PieChartSectionData> pieSections = [
      PieChartSectionData(
        color: Colors.green,
        value: normal,
        title: '${normal.toStringAsFixed(0)}%',
        radius: 50,
        titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
      ),
      PieChartSectionData(
        color: Colors.orange,
        value: elevated,
        title: '${elevated.toStringAsFixed(0)}%',
        radius: 50,
        titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
      ),
      PieChartSectionData(
        color: Colors.red,
        value: high,
        title: '${high.toStringAsFixed(0)}%',
        radius: 50,
        titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
      ),
    ];

    return Card(
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Heart Rate Zones',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                SizedBox(
                  width: 140,
                  height: 140,
                  child: PieChart(
                    PieChartData(
                      sections: pieSections,
                      centerSpaceRadius: 25,
                      sectionsSpace: 2,
                    ),
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildZoneLegend(context, 'Normal Zone', '110-140 BPM', Colors.green, normal.round()),
                      _buildZoneLegend(context, 'Elevated Zone', '140-150 BPM', Colors.orange, elevated.round()),
                      _buildZoneLegend(context, 'High Zone', '150+ BPM', Colors.red, high.round()),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildZoneLegend(
      BuildContext context, String label, String range, Color color, int percentage) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Container(width: 10, height: 10, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                Text(range, style: TextStyle(fontSize: 10, color: Theme.of(context).colorScheme.onSurfaceVariant)),
              ],
            ),
          ),
          Text(
            '$percentage%',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailedStats(BuildContext context, int minHR, int maxHR, int avgHR) {
    return Card(
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Detailed Statistics',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 15),
            Table(
              columnWidths: const {
                0: FlexColumnWidth(1.5),
                1: FlexColumnWidth(1),
                2: FlexColumnWidth(1),
              },
              children: [
                _buildTableRow('Metric', 'Value', const Text('Status')),
                _buildTableRow('Average HR', '$avgHR BPM', _buildStatusBadge('Normal', Colors.green)),
                _buildTableRow('Maximum HR', '$maxHR BPM', _buildStatusBadge(maxHR > 150 ? 'High' : 'Normal', maxHR > 150 ? Colors.red : Colors.green)),
                _buildTableRow('Minimum HR', '$minHR BPM', _buildStatusBadge('Normal', Colors.green)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  TableRow _buildTableRow(String metric, String value, Widget status) {
    return TableRow(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Text(metric),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: status,
        ),
      ],
    );
  }

  Widget _buildStatusBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.bold),
      ),
    );
  }

  Color _getHRColor(double hr) {
    if (hr < 110) return Colors.blue;
    if (hr <= 140) return Colors.green;
    if (hr <= 150) return Colors.orange;
    return Colors.red;
  }
}
