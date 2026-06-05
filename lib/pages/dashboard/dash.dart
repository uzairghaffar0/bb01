import 'package:flutter/material.dart';
import '../../widgets/navigation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage>
    with SingleTickerProviderStateMixin {
  String babyName = "";
  bool isLoading = true;

  File? babyImage;
  final ImagePicker picker = ImagePicker();

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    getUserData();
    _setupFCMListeners();

    // Pulse animation for live indicator
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  /// Listen for FCM push notifications while the app is in the foreground
  void _setupFCMListeners() {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      final notification = message.notification;
      final data = message.data;

      if (notification != null && mounted) {
        _showAlertDialog(
          title: notification.title ?? 'Alert',
          body: notification.body ?? '',
          metric: data['metric'] ?? '',
          value: data['value'] ?? '',
          status: data['status'] ?? '',
        );
      }
    });
  }

  /// Show a beautiful alert dialog for push notifications
  void _showAlertDialog({
    required String title,
    required String body,
    required String metric,
    required String value,
    required String status,
  }) {
    Color alertColor = Colors.redAccent;
    IconData alertIcon = Icons.warning_rounded;

    if (metric.toLowerCase().contains('cry')) {
      alertColor = Colors.purple;
      alertIcon = Icons.record_voice_over;
    } else if (metric.toLowerCase().contains('temp')) {
      alertColor = Colors.orange;
      alertIcon = Icons.thermostat;
    } else if (metric.toLowerCase().contains('heart')) {
      alertColor = Colors.redAccent;
      alertIcon = Icons.favorite;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: alertColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(alertIcon, color: alertColor, size: 28),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(title,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 18)),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(body, style: const TextStyle(fontSize: 15)),
            if (value.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: alertColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(metric,
                        style: TextStyle(
                            color: alertColor, fontWeight: FontWeight.w600)),
                    const SizedBox(width: 8),
                    Text(value,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: alertColor,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(status,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 12)),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Dismiss'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.pushNamed(context, '/notifications');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: alertColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('View Details'),
          ),
        ],
      ),
    );
  }

  Future<void> pickBabyImage() async {
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );

    if (image != null) {
      setState(() {
        babyImage = File(image.path);
      });
    }
  }

  Future<void> getUserData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user != null) {
        final snapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        if (snapshot.exists && mounted) {
          setState(() {
            babyName = snapshot['babyName'] ?? 'Baby';
            isLoading = false;
          });
        }
      }
    } catch (e) {
      print(e.toString());
    }
  }

  Widget _buildDashboardUI(
    BuildContext context, {
    required double temp,
    required String sleep,
    required int heartRate,
    required String cry,
    required double roomTemp,
    required double humidity,
    required String lastSyncText,
    required bool isLive,
  }) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Title row with live indicator
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Dashboard',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(width: 10),
              if (isLive)
                FadeTransition(
                  opacity: _pulseAnimation,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: Colors.green.withOpacity(0.4), width: 1),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.circle, color: Colors.green, size: 8),
                        SizedBox(width: 4),
                        Text('LIVE',
                            style: TextStyle(
                                color: Colors.green,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1)),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),

          // Baby info
          Column(
            children: [
              GestureDetector(
                onTap: pickBabyImage,
                child: CircleAvatar(
                  radius: 45,
                  backgroundColor: theme.cardColor,
                  backgroundImage: babyImage != null
                      ? FileImage(babyImage!)
                      : const AssetImage('images/baby.png') as ImageProvider,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                babyName,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              if (FirebaseAuth.instance.currentUser != null) ...[
                const SizedBox(height: 4),
                Text(
                  'Account: ${FirebaseAuth.instance.currentUser!.email}\n(UID: ${FirebaseAuth.instance.currentUser!.uid})',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    color: theme.colorScheme.onSurfaceVariant.withOpacity(0.7),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    isLive ? Icons.sync : Icons.sync_disabled,
                    size: 14,
                    color: isLive ? Colors.green : theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    lastSyncText,
                    style: TextStyle(
                        color: theme.colorScheme.onSurfaceVariant, fontSize: 14),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 30),

          // Health Status Section
          Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: theme.shadowColor.withOpacity(0.05),
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

                // Row of 4 Health Metrics with live data
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _healthMetricCard(
                        context,
                        Icons.thermostat,
                        'Temp',
                        '${temp.toStringAsFixed(1)}°C',
                        _getTempColor(temp),
                        _getTempColor(temp).withOpacity(0.1),
                      ),
                    ),
                    Expanded(
                      child: _healthMetricCard(
                        context,
                        Icons.bedtime,
                        'Sleep',
                        sleep,
                        _getSleepColor(sleep),
                        _getSleepColor(sleep).withOpacity(0.1),
                      ),
                    ),
                    Expanded(
                      child: _healthMetricCard(
                        context,
                        Icons.favorite,
                        'Heart Rate',
                        '$heartRate BPM',
                        _getHeartRateColor(heartRate),
                        _getHeartRateColor(heartRate).withOpacity(0.1),
                      ),
                    ),
                    Expanded(
                      child: _healthMetricCard(
                        context,
                        _getCryIcon(cry),
                        'Cry',
                        _getCryDisplayText(cry),
                        _getCryColor(cry),
                        _getCryColor(cry).withOpacity(0.1),
                      ),
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
                    _latestScanItem(
                        context,
                        'Temperature',
                        '${temp.toStringAsFixed(1)}°C',
                        _getTempStatus(temp),
                        _getTempColor(temp)),
                    _latestScanItem(
                        context,
                        'Heart Rate',
                        '$heartRate BPM',
                        _getHeartRateStatus(heartRate),
                        _getHeartRateColor(heartRate)),
                    _latestScanItem(context, 'Sleep', sleep,
                        _getSleepStatus(sleep), _getSleepColor(sleep)),
                    _latestScanItem(
                        context,
                        'Cry Analysis',
                        _getCryDisplayText(cry),
                        _getCryStatus(cry),
                        _getCryColor(cry)),
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
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: theme.shadowColor.withOpacity(0.05),
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
                      context,
                      Icons.thermostat,
                      '${roomTemp.toStringAsFixed(1)}°C',
                      'Room Temp',
                      Colors.orange.shade400,
                      Colors.orange.shade50,
                    ),
                    _environmentCard(
                      context,
                      Icons.water_drop,
                      '${humidity.toStringAsFixed(0)}%',
                      'Humidity',
                      Colors.blue.shade400,
                      Colors.blue.shade50,
                    ),
                  ],
                ),

                // Latest Environment Scans
                const SizedBox(height: 20),
                const Text(
                  'Latest Scans',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 10),
                Column(
                  children: [
                    _latestScanItem(
                        context,
                        'Room Temp',
                        '${roomTemp.toStringAsFixed(1)}°C',
                        _getRoomTempStatus(roomTemp),
                        Colors.orange.shade400),
                    _latestScanItem(
                        context,
                        'Humidity',
                        '${humidity.toStringAsFixed(0)}%',
                        _getHumidityStatus(humidity),
                        Colors.blue.shade400),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  //  Color & Status Helpers (dynamic based on values)
  // ═══════════════════════════════════════════════════════

  Color _getTempColor(double temp) {
    if (temp < 36.5) return Colors.blue;
    if (temp <= 37.0) return Colors.green;
    if (temp <= 37.5) return Colors.orange;
    return Colors.red;
  }

  String _getTempStatus(double temp) {
    if (temp < 36.5) return 'Low';
    if (temp <= 37.0) return 'Normal';
    if (temp <= 37.5) return 'Elevated';
    return '⚠ Fever';
  }

  Color _getHeartRateColor(int hr) {
    if (hr < 110) return Colors.blue;
    if (hr <= 140) return Colors.green;
    if (hr <= 150) return Colors.orange;
    return Colors.red;
  }

  String _getHeartRateStatus(int hr) {
    if (hr < 110) return 'Low';
    if (hr <= 140) return 'Normal';
    if (hr <= 150) return 'Elevated';
    return '⚠ High';
  }

  Color _getSleepColor(String sleep) {
    switch (sleep.toLowerCase()) {
      case 'deep sleep':
        return Colors.indigo;
      case 'light sleep':
        return Colors.blue;
      case 'rem':
        return Colors.purple;
      case 'awake':
        return Colors.orange;
      default:
        return Colors.blue.shade400;
    }
  }

  String _getSleepStatus(String sleep) {
    switch (sleep.toLowerCase()) {
      case 'deep sleep':
        return 'Resting well';
      case 'light sleep':
        return 'Light rest';
      case 'rem':
        return 'Dreaming';
      case 'awake':
        return 'Active';
      default:
        return 'Monitoring';
    }
  }

  Color _getCryColor(String cry) {
    if (cry.toLowerCase().contains('crying') || cry.toLowerCase().contains('hunger') || cry.toLowerCase().contains('pain')) {
      return Colors.red;
    }
    if (cry.toLowerCase() == 'quiet') return Colors.green;
    return Colors.purple.shade400;
  }

  String _getCryDisplayText(String cry) {
    // Extract the reason from format like "Crying (Hunger)"
    if (cry.contains('(') && cry.contains(')')) {
      final reason = cry.substring(cry.indexOf('(') + 1, cry.indexOf(')'));
      return reason;
    }
    return cry;
  }

  IconData _getCryIcon(String cry) {
    if (cry.toLowerCase() == 'quiet') return Icons.sentiment_satisfied;
    if (cry.toLowerCase().contains('hunger')) return Icons.restaurant;
    if (cry.toLowerCase().contains('pain')) return Icons.healing;
    if (cry.toLowerCase().contains('tired')) return Icons.bedtime;
    return Icons.record_voice_over;
  }

  String _getCryStatus(String cry) {
    if (cry.toLowerCase() == 'quiet') return 'Happy';
    if (cry.toLowerCase().contains('crying')) return '⚠ Needs attention';
    return cry;
  }

  String _getRoomTempStatus(double temp) {
    if (temp < 18) return 'Too Cold';
    if (temp <= 24) return 'Comfortable';
    return 'Too Warm';
  }

  String _getHumidityStatus(double h) {
    if (h < 40) return 'Too Dry';
    if (h <= 60) return 'Comfortable';
    return 'Too Humid';
  }

  // ═══════════════════════════════════════════════════════
  //  Widget Helpers
  // ═══════════════════════════════════════════════════════

  static Widget _healthMetricCard(
    BuildContext context,
    IconData icon,
    String label,
    String value,
    Color iconColor,
    Color bgColor,
  ) {
    return Column(
      children: [
        Container(
          height: 60,
          width: 60,
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark
                ? iconColor.withOpacity(0.15)
                : bgColor,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: iconColor.withOpacity(0.2),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Icon(icon, color: iconColor, size: 28),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
          ),
          textAlign: TextAlign.center,
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  static Widget _environmentCard(
    BuildContext context,
    IconData icon,
    String value,
    String label,
    Color iconColor,
    Color bgColor,
  ) {
    final theme = Theme.of(context);
    return Container(
      width: 140,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: theme.brightness == Brightness.dark
            ? iconColor.withOpacity(0.15)
            : bgColor,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: iconColor.withOpacity(0.1),
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
              color: theme.cardColor,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: iconColor.withOpacity(0.2),
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
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  static Widget _latestScanItem(BuildContext context, String title,
      String value, String statusText, Color color) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
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
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              statusText,
              style: TextStyle(
                fontSize: 11,
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

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

  // ═══════════════════════════════════════════════════════
  //  BUILD — StreamBuilder for real-time Firestore updates
  // ═══════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .collection('health_metrics')
              .doc('latest')
              .snapshots(),
          builder: (context, snapshot) {
            double temp = 36.8;
            String sleep = 'Normal';
            int heartRate = 128;
            String cry = 'Quiet';
            double roomTemp = 22.5;
            double humidity = 65.0;
            String lastSyncText = 'Waiting for data...';
            bool isLive = false;

            if (snapshot.hasError) {
              final err = snapshot.error.toString();
              if (err.contains('permission') || err.contains('PERMISSION_DENIED')) {
                print('❌ FIRESTORE PERMISSION DENIED: The security rules are blocking reads from users/{uid}/health_metrics/latest. Fix your Firestore rules in Firebase Console.');
              } else {
                print('❌ Firestore StreamBuilder Error: $err');
              }
            }

            print('StreamBuilder connectionState: ${snapshot.connectionState}, hasData: ${snapshot.hasData}, exists: ${snapshot.hasData ? snapshot.data!.exists : "N/A"}');
            if (snapshot.hasData && snapshot.data!.exists) {
              print('StreamBuilder data received: ${snapshot.data!.data()}');
            }

            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasData && snapshot.data!.exists) {
              final data = snapshot.data!.data() as Map<String, dynamic>?;
              if (data != null) {
                temp = (data['temperature'] as num?)?.toDouble() ?? temp;
                heartRate = (data['heartRate'] as num?)?.toInt() ?? heartRate;
                sleep = data['sleepStatus'] as String? ?? sleep;
                cry = data['cryStatus'] as String? ?? cry;
                roomTemp =
                    (data['roomTemperature'] as num?)?.toDouble() ?? roomTemp;
                humidity = (data['humidity'] as num?)?.toDouble() ?? humidity;
                isLive = true;

                if (data['lastUpdated'] is Timestamp) {
                  final Timestamp t = data['lastUpdated'] as Timestamp;
                  final diff = DateTime.now().difference(t.toDate());
                  if (diff.inSeconds < 15) {
                    lastSyncText = 'Live — Just now';
                  } else if (diff.inSeconds < 60) {
                    lastSyncText = 'Last sync: ${diff.inSeconds}s ago';
                  } else if (diff.inMinutes < 60) {
                    lastSyncText = 'Last sync: ${diff.inMinutes}m ago';
                  } else {
                    lastSyncText = 'Last sync: ${diff.inHours}h ago';
                    isLive = false;
                  }
                } else if (data['lastUpdated'] is String) {
                  lastSyncText = 'Last sync: ${data['lastUpdated']}';
                }
              }
            }

            return _buildDashboardUI(
              context,
              temp: temp,
              sleep: sleep,
              heartRate: heartRate,
              cry: cry,
              roomTemp: roomTemp,
              humidity: humidity,
              lastSyncText: lastSyncText,
              isLive: isLive,
            );
          },
        ),
      ),
      bottomNavigationBar: const AppBottomNav(currentIndex: 0),
    );
  }
}
