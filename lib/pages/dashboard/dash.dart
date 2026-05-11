import 'package:flutter/material.dart';
import '../../widgets/navigation.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  Widget _buildDashboardUI() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Text(
            'Dashboard',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 10),

          // Baby info
          Column(
            children: [
              const CircleAvatar(
                radius: 45,
                backgroundColor: Colors.white,
                backgroundImage: AssetImage(
                  'images/baby.png',
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Emma',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  color: Colors.black,
                ),
              ),
              const Text(
                'Last sync: 5 minutes ago',
                style: TextStyle(color: Colors.grey, fontSize: 14),
              ),
            ],
          ),

          const SizedBox(height: 30),

          // Health Status Section
          Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Health Status',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 15),

                // Row of 4 Health Metrics with colorful icons
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _healthMetricCard(
                      Icons.thermostat,
                      'Temp',
                      Colors.orange.shade400,
                      Colors.orange.shade50,
                    ),
                    _healthMetricCard(
                      Icons.bedtime,
                      'Sleep',
                      Colors.blue.shade400,
                      Colors.blue.shade50,
                    ),
                    _healthMetricCard(
                      Icons.favorite,
                      'Heart Rate',
                      Colors.red.shade400,
                      Colors.red.shade50,
                    ),
                    _healthMetricCard(
                      Icons.record_voice_over,
                      'Cry',
                      Colors.purple.shade400,
                      Colors.purple.shade50,
                    ),
                  ],
                ),

                // Latest Health Scans Section
                const SizedBox(height: 20),
                const Text(
                  'Latest Scans',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 10),
                Column(
                  children: [
                    _latestScanItem('Temperature', '36.8°C', '2 min ago',
                        Colors.orange.shade400),
                    _latestScanItem('Heart Rate', '128 BPM', '5 min ago',
                        Colors.red.shade400),
                    _latestScanItem('Sleep', 'Sleeping', '10 min ago',
                        Colors.blue.shade400),
                    _latestScanItem('Cry Analysis', 'No crying', '15 min ago',
                        Colors.purple.shade400),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 25),

          // Environment Status Section
          Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Environment Status',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _environmentCard(
                      Icons.thermostat,
                      '22.5℃',
                      'Temperature',
                      Colors.orange.shade400,
                      Colors.orange.shade50,
                    ),
                    _environmentCard(
                      Icons.water_drop,
                      '150tm',
                      'Humidity',
                      Colors.blue.shade400,
                      Colors.blue.shade50,
                    ),
                  ],
                ),

                // Latest Environment Scans Section
                const SizedBox(height: 20),
                const Text(
                  'Latest Scans',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 10),
                Column(
                  children: [
                    _latestScanItem('Room Temp', '22.5℃', '1 min ago',
                        Colors.orange.shade400),
                    _latestScanItem(
                        'Humidity', '65%', '1 min ago', Colors.blue.shade400),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Helper widget for health metrics with colorful icons
  static Widget _healthMetricCard(
    IconData icon,
    String label,
    Color iconColor,
    Color bgColor,
  ) {
    return Column(
      children: [
        Container(
          height: 70,
          width: 70,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: bgColor,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: iconColor.withValues(alpha: 0.2),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Icon(icon, color: iconColor, size: 35),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.grey.shade700,
          ),
        ),
      ],
    );
  }

  // Helper widget for environment cards with colorful icons
  static Widget _environmentCard(
    IconData icon,
    String value,
    String label,
    Color iconColor,
    Color bgColor,
  ) {
    return Container(
      width: 140,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: iconColor.withValues(alpha: 0.1),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: iconColor.withValues(alpha: 0.2),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(icon, color: iconColor, size: 28),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  // Helper widget for latest scan items
  static Widget _latestScanItem(
      String title, String value, String time, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              _getIconForScan(title),
              color: color,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
          Text(
            time,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  // Helper function to get icon for scan type
  static IconData _getIconForScan(String title) {
    switch (title.toLowerCase()) {
      case 'temperature':
      case 'room temp':
        return Icons.thermostat;
      case 'heart rate':
        return Icons.favorite;
      case 'sleep':
        return Icons.bedtime;
      case 'cry analysis':
        return Icons.record_voice_over;
      case 'humidity':
        return Icons.water_drop;
      default:
        return Icons.info;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5FBFF),
      body: SafeArea(child: _buildDashboardUI()),
      bottomNavigationBar: const AppBottomNav(currentIndex: 0),
    );
  }
}
