import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SleepPage extends StatelessWidget {
  const SleepPage({super.key});

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
            .collection('sleep_history')
            .orderBy('date', descending: true)
            .limit(7)
            .snapshots(),
        builder: (context, snapshot) {
          String totalDurationText = '8h 24m';
          int sleepQuality = 82;
          String bedTimeStr = '9:45 PM';
          String wakeTimeStr = '6:15 AM';
          
          List<FlSpot> sleepPattern = [];
          Map<String, Map<String, dynamic>> stages = {
            'Deep Sleep': {'duration': '3h 45m', 'percentage': 45, 'color': Colors.indigo},
            'Light Sleep': {'duration': '3h 15m', 'percentage': 39, 'color': Colors.blue},
            'REM Sleep': {'duration': '1h 24m', 'percentage': 16, 'color': Colors.purple},
          };

          double avgSleepVal = 8.2;

          if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
            final docs = snapshot.data!.docs;
            final latestDoc = docs.first.data() as Map<String, dynamic>;

            // Parse duration
            final totalMinutes = (latestDoc['totalDurationMinutes'] as num?)?.toInt() ?? 504;
            totalDurationText = '${totalMinutes ~/ 60}h ${totalMinutes % 60}m';

            // Sleep Quality
            sleepQuality = (latestDoc['sleepQuality'] as num?)?.toInt() ?? 82;

            // Bed and Wake time
            final bedTimeTS = latestDoc['bedTime'] as Timestamp?;
            final wakeTimeTS = latestDoc['wakeTime'] as Timestamp?;
            if (bedTimeTS != null) {
              final bt = bedTimeTS.toDate();
              bedTimeStr = '${bt.hour > 12 ? bt.hour - 12 : (bt.hour == 0 ? 12 : bt.hour)}:${bt.minute.toString().padLeft(2, '0')} ${bt.hour >= 12 ? 'PM' : 'AM'}';
            }
            if (wakeTimeTS != null) {
              final wt = wakeTimeTS.toDate();
              wakeTimeStr = '${wt.hour > 12 ? wt.hour - 12 : (wt.hour == 0 ? 12 : wt.hour)}:${wt.minute.toString().padLeft(2, '0')} ${wt.hour >= 12 ? 'PM' : 'AM'}';
            }

            // Stages
            final stageData = latestDoc['stages'] as Map<String, dynamic>?;
            if (stageData != null) {
              final deep = (stageData['deepMinutes'] as num?)?.toInt() ?? 180;
              final light = (stageData['lightMinutes'] as num?)?.toInt() ?? 220;
              final rem = (stageData['remMinutes'] as num?)?.toInt() ?? 80;
              final totalMins = deep + light + rem;
              
              if (totalMins > 0) {
                stages = {
                  'Deep Sleep': {
                    'duration': '${deep ~/ 60}h ${deep % 60}m',
                    'percentage': ((deep / totalMins) * 100).round(),
                    'color': Colors.indigo
                  },
                  'Light Sleep': {
                    'duration': '${light ~/ 60}h ${light % 60}m',
                    'percentage': ((light / totalMins) * 100).round(),
                    'color': Colors.blue
                  },
                  'REM Sleep': {
                    'duration': '${rem ~/ 60}h ${rem % 60}m',
                    'percentage': ((rem / totalMins) * 100).round(),
                    'color': Colors.purple
                  },
                };
              }
            }

            // Pattern line chart spots
            final patternList = latestDoc['pattern'] as List<dynamic>?;
            if (patternList != null) {
              for (int idx = 0; idx < patternList.length; idx++) {
                final item = patternList[idx] as Map<String, dynamic>;
                final depth = (item['depth'] as num?)?.toDouble() ?? 50.0;
                sleepPattern.add(FlSpot(idx.toDouble(), depth));
              }
            }

            // Average Sleep over the week
            double sumDuration = 0;
            for (var doc in docs) {
              final d = doc.data() as Map<String, dynamic>;
              sumDuration += (d['totalDurationMinutes'] as num?)?.toDouble() ?? 500;
            }
            avgSleepVal = (sumDuration / docs.length) / 60.0;
          }

          // Fallbacks if list is empty
          if (sleepPattern.isEmpty) {
            sleepPattern = [
              const FlSpot(0, 0),   // Awake
              const FlSpot(1, 10),  // Light
              const FlSpot(2, 85),  // Deep
              const FlSpot(3, 90),  // Deep
              const FlSpot(4, 50),  // Light
              const FlSpot(5, 75),  // REM
              const FlSpot(6, 0),   // Awake
            ];
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSleepSummary(context, totalDurationText, sleepQuality),
                const SizedBox(height: 20),
                _buildSleepChart(context, sleepPattern),
                const SizedBox(height: 20),
                _buildSleepStages(context, stages),
                const SizedBox(height: 20),
                _buildSleepStats(context, avgSleepVal, bedTimeStr, wakeTimeStr, sleepQuality),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSleepSummary(BuildContext context, String durationText, int quality) {
    String qualityText = 'Normal';
    Color qualityColor = Colors.green;
    if (quality >= 85) {
      qualityText = 'Excellent Sleep';
    } else if (quality >= 70) {
      qualityText = 'Good Sleep Quality';
    } else {
      qualityText = 'Restless Sleep';
      qualityColor = Colors.orange;
    }

    return Card(
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Last Night\'s Sleep',
                  style: TextStyle(fontSize: 14, color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 5),
                Text(
                  durationText,
                  style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Colors.indigo),
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    Icon(Icons.check_circle, color: qualityColor, size: 16),
                    const SizedBox(width: 5),
                    Text(
                      qualityText,
                      style: TextStyle(color: qualityColor, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.indigo.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.nights_stay, color: Colors.indigo, size: 40),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSleepChart(BuildContext context, List<FlSpot> sleepData) {
    return Card(
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Sleep Pattern',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: true,
                    getDrawingHorizontalLine: (value) {
                      return FlLine(
                        color: Theme.of(context).dividerColor,
                        strokeWidth: 1,
                      );
                    },
                  ),
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 30,
                        getTitlesWidget: (value, meta) {
                          // Return dynamic labels based on index
                          int idx = value.toInt();
                          if (idx % 2 == 0) {
                            return Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Text('T+$idx h', style: const TextStyle(fontSize: 10)),
                            );
                          }
                          return const SizedBox();
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 50,
                        getTitlesWidget: (value, meta) {
                          if (value == 0) return const Text('Awake', style: TextStyle(fontSize: 10));
                          if (value == 50) return const Text('Light', style: TextStyle(fontSize: 10));
                          if (value == 100) return const Text('Deep', style: TextStyle(fontSize: 10));
                          return const SizedBox();
                        },
                      ),
                    ),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(
                    show: true,
                    border: Border.all(color: Theme.of(context).dividerColor),
                  ),
                  minX: 0,
                  maxX: (sleepData.length - 1).toDouble(),
                  minY: 0,
                  maxY: 100,
                  lineBarsData: [
                    LineChartBarData(
                      spots: sleepData,
                      isCurved: true,
                      color: Colors.indigo,
                      barWidth: 3,
                      isStrokeCapRound: true,
                      belowBarData: BarAreaData(
                        show: true,
                        gradient: LinearGradient(
                          colors: [
                            Colors.indigo.withOpacity(0.3),
                            Colors.indigo.withOpacity(0.1),
                          ],
                        ),
                      ),
                      dotData: const FlDotData(show: false),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Sleep Depth', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12)),
                Text('Duration', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSleepStages(BuildContext context, Map<String, Map<String, dynamic>> stages) {
    return Card(
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Sleep Stages',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Column(
              children: stages.entries.map((entry) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(
                                  color: entry.value['color'] as Color,
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(entry.key, style: const TextStyle(fontWeight: FontWeight.w500)),
                            ],
                          ),
                          Text('${entry.value['duration']} (${entry.value['percentage']}%)'),
                        ],
                      ),
                      const SizedBox(height: 5),
                      LinearProgressIndicator(
                        value: (entry.value['percentage'] as int) / 100,
                        backgroundColor: Theme.of(context).dividerColor,
                        color: entry.value['color'] as Color,
                        minHeight: 6,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSleepStats(
      BuildContext context, double avgSleep, String bedTime, String wakeTime, int quality) {
    return Card(
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Weekly Sleep Statistics',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 15),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildStatItem(context, 'Avg Sleep', '${avgSleep.toStringAsFixed(1)}h', Icons.nights_stay, Colors.indigo),
                _buildStatItem(context, 'Bed Time', bedTime, Icons.schedule, Colors.blue),
                _buildStatItem(context, 'Wake Time', wakeTime, Icons.wb_sunny, Colors.orange),
              ],
            ),
            const SizedBox(height: 15),
            const Divider(),
            const SizedBox(height: 10),
            Text(
              'Sleep Quality: $quality/100',
              style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 5),
            LinearProgressIndicator(
              value: quality / 100.0,
              backgroundColor: Theme.of(context).dividerColor,
              color: Colors.green,
              minHeight: 8,
              borderRadius: BorderRadius.circular(4),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(
      BuildContext context, String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }
}
