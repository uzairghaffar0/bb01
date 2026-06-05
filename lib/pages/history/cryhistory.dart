import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CryPage extends StatelessWidget {
  const CryPage({super.key});

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
            .collection('cries')
            .orderBy('timestamp', descending: true)
            .limit(50)
            .snapshots(),
        builder: (context, snapshot) {
          int todayCries = 0;
          double avgDurationSecs = 0;
          String mostCommonReason = 'None';
          List<Map<String, dynamic>> recentCries = [];
          Map<String, double> reasonDistribution = {
            'Hunger': 0,
            'Sleepy': 0,
            'Discomfort': 0,
            'Need Burping': 0,
            'Other': 0,
          };
          List<FlSpot> patternSpots = [];

          if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
            final docs = snapshot.data!.docs;
            final now = DateTime.now();
            final todayMidnight = DateTime(now.year, now.month, now.day);
            double totalDuration = 0;
            Map<String, int> reasonCounts = {};

            // Helper lists for hourly pattern grouping
            Map<int, List<double>> hourlyIntensities = {};

            for (var doc in docs) {
              final data = doc.data() as Map<String, dynamic>;
              final ts = data['timestamp'] as Timestamp?;
              final reason = data['reason'] as String? ?? 'Other';
              final duration = (data['durationSeconds'] as num?)?.toInt() ?? 0;
              final intensity = (data['intensity'] as num?)?.toDouble() ?? 50.0;

              if (ts != null) {
                final dt = ts.toDate();
                
                // Count if today
                if (dt.isAfter(todayMidnight)) {
                  todayCries++;
                }

                // Add to recent list
                final minutesStr = '${(duration ~/ 60)}:${(duration % 60).toString().padLeft(2, '0')}';
                final timeStr = '${dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour)}:${dt.minute.toString().padLeft(2, '0')} ${dt.hour >= 12 ? 'PM' : 'AM'}';
                
                recentCries.add({
                  'time': timeStr,
                  'reason': reason,
                  'duration': minutesStr,
                  'intensity': intensity.round(),
                  'timestamp': dt,
                });

                // Cumulative calculations
                totalDuration += duration;
                reasonCounts[reason] = (reasonCounts[reason] ?? 0) + 1;

                // Group by hour for the trend chart
                final hr = dt.hour;
                hourlyIntensities[hr] = (hourlyIntensities[hr] ?? [])..add(intensity);
              }
            }

            // Average Duration
            avgDurationSecs = docs.isEmpty ? 0 : totalDuration / docs.length;

            // Most Common Reason
            if (reasonCounts.isNotEmpty) {
              var sortedReasons = reasonCounts.entries.toList()
                ..sort((a, b) => b.value.compareTo(a.value));
              mostCommonReason = sortedReasons.first.key;
            }

            // Reason percentages
            double totalReasons = docs.length.toDouble();
            if (totalReasons > 0) {
              reasonCounts.forEach((r, count) {
                if (reasonDistribution.containsKey(r)) {
                  reasonDistribution[r] = (count / totalReasons) * 100;
                } else {
                  reasonDistribution['Other'] = (reasonDistribution['Other'] ?? 0) + (count / totalReasons) * 100;
                }
              });
            }

            // Pattern line chart spots
            final sortedHours = hourlyIntensities.keys.toList()..sort();
            for (var hr in sortedHours) {
              final intensities = hourlyIntensities[hr]!;
              final avgIntensity = intensities.reduce((a, b) => a + b) / intensities.length;
              patternSpots.add(FlSpot(hr.toDouble(), avgIntensity));
            }
          }

          // Fallbacks for empty states
          if (recentCries.isEmpty) {
            recentCries = [
              {'time': '2:30 PM', 'reason': 'Hunger', 'duration': '4:12', 'intensity': 85},
              {'time': '11:45 AM', 'reason': 'Sleepy', 'duration': '3:45', 'intensity': 60},
              {'time': '9:15 AM', 'reason': 'Discomfort', 'duration': '5:20', 'intensity': 90},
            ];
            reasonDistribution = {
              'Hunger': 45,
              'Sleepy': 25,
              'Discomfort': 15,
              'Need Burping': 10,
              'Other': 5,
            };
            patternSpots = [
              const FlSpot(0, 20),
              const FlSpot(6, 45),
              const FlSpot(12, 60),
              const FlSpot(18, 50),
              const FlSpot(24, 40),
            ];
            todayCries = 8;
            avgDurationSecs = 252; // 4.2 min
            mostCommonReason = 'Hunger';
          }

          final avgMinStr = '${(avgDurationSecs / 60).toStringAsFixed(1)}m';

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSummaryCards(context, todayCries, avgMinStr, mostCommonReason),
                const SizedBox(height: 20),
                _buildLineChart(context, patternSpots),
                const SizedBox(height: 20),
                _buildReasonChart(context, reasonDistribution),
                const SizedBox(height: 20),
                _buildRecentCries(context, recentCries),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSummaryCards(BuildContext context, int todayCount, String avgDuration, String mostReason) {
    return Row(
      children: [
        Expanded(
          child: _buildSummaryCard(
            context,
            'Today\'s Cries',
            '$todayCount',
            Icons.mic,
            Colors.purple,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildSummaryCard(
            context,
            'Avg Duration',
            avgDuration,
            Icons.timer,
            Colors.blue,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildSummaryCard(
            context,
            'Most Reason',
            mostReason,
            _getReasonIcon(mostReason),
            Colors.orange,
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard(
      BuildContext context, String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(fontSize: 10, color: Theme.of(context).colorScheme.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildLineChart(BuildContext context, List<FlSpot> patternSpots) {
    return Card(
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Cry Pattern (Last 24 Hours)',
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
                    getDrawingVerticalLine: (value) {
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
                          List<String> hours = ['12AM', '6AM', '12PM', '6PM', '12AM'];
                          int hrVal = value.toInt();
                          if (hrVal % 6 == 0 && hrVal >= 0 && hrVal <= 24) {
                            return Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Text(hours[hrVal ~/ 6]),
                            );
                          }
                          return const SizedBox();
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        getTitlesWidget: (value, meta) {
                          return Text('${value.toInt()}%');
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
                  maxX: 24,
                  minY: 0,
                  maxY: 100,
                  lineBarsData: [
                    LineChartBarData(
                      spots: patternSpots,
                      isCurved: true,
                      color: Colors.purple,
                      barWidth: 3,
                      isStrokeCapRound: true,
                      belowBarData: BarAreaData(
                        show: true,
                        gradient: LinearGradient(
                          colors: [
                            Colors.purple.withOpacity(0.3),
                            Colors.purple.withOpacity(0.1),
                          ],
                        ),
                      ),
                      dotData: const FlDotData(show: true),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Time of Day', style: TextStyle(fontSize: 11, color: Colors.grey)),
                Text('Avg Intensity (%)', style: TextStyle(fontSize: 11, color: Colors.grey)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReasonChart(BuildContext context, Map<String, double> reasonData) {
    final List<BarChartGroupData> barGroups = [];
    final keys = reasonData.keys.toList();

    for (int i = 0; i < keys.length; i++) {
      final key = keys[i];
      final val = reasonData[key]!;
      barGroups.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: val,
              color: _getReasonColor(key),
              width: 18,
              borderRadius: BorderRadius.circular(4),
            ),
          ],
        ),
      );
    }

    return Card(
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Cry Reasons Distribution',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 200,
              child: BarChart(
                BarChartData(
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          int index = value.toInt();
                          return index >= 0 && index < keys.length
                              ? Padding(
                                  padding: const EdgeInsets.only(top: 8.0),
                                  child: Text(
                                    keys[index],
                                    style: const TextStyle(fontSize: 9),
                                    textAlign: TextAlign.center,
                                  ),
                                )
                              : const SizedBox();
                        },
                        reservedSize: 40,
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          return Text('${value.toInt()}%', style: const TextStyle(fontSize: 9));
                        },
                        reservedSize: 30,
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
                  maxY: 100,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentCries(BuildContext context, List<Map<String, dynamic>> recentCries) {
    return Card(
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Recent Cries',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Column(
              children: recentCries.map((cry) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: _getReasonColor(cry['reason'] as String).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          _getReasonIcon(cry['reason'] as String),
                          color: _getReasonColor(cry['reason'] as String),
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              cry['reason'] as String,
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            Text(
                              'Duration: ${cry['duration']} min',
                              style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(cry['time'] as String),
                          Text(
                            '${cry['intensity']}% intensity',
                            style: TextStyle(
                              fontSize: 12,
                              color: _getIntensityColor(cry['intensity'] as int),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
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

  Color _getReasonColor(String reason) {
    switch (reason) {
      case 'Hunger':
        return Colors.orange;
      case 'Sleepy':
        return Colors.blue;
      case 'Discomfort':
        return Colors.red;
      case 'Need Burping':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  Color _getIntensityColor(int intensity) {
    if (intensity >= 80) return Colors.red;
    if (intensity >= 60) return Colors.orange;
    return Colors.green;
  }

  IconData _getReasonIcon(String reason) {
    switch (reason) {
      case 'Hunger':
        return Icons.local_dining;
      case 'Sleepy':
        return Icons.bedtime;
      case 'Discomfort':
        return Icons.sick;
      case 'Need Burping':
        return Icons.airline_seat_flat;
      default:
        return Icons.help;
    }
  }
}
