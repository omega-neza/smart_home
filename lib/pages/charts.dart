import 'dart:async';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

void main() {
  runApp(const MaterialApp(home: RealTimeChartPage()));
}

class RealTimeChartPage extends StatelessWidget {
  const RealTimeChartPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Light Sensor',
          style: TextStyle(color: Colors.blue),
        ),
        backgroundColor: Colors.white, // Set the AppBar color to blue
      ),
      body: const RealTimeChart(),
    );
  }
}

class RealTimeChart extends StatefulWidget {
  const RealTimeChart({super.key});

  @override
  _RealTimeChartState createState() => _RealTimeChartState();
}

class _RealTimeChartState extends State<RealTimeChart> {
  late List<_ChartData> _chartData;
  late Timer _timer;
  late FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin;

  @override
  void initState() {
    super.initState();
    _chartData = <_ChartData>[];
    _initializeNotifications();
    _startTimer();
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  void _initializeNotifications() {
    flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);
    flutterLocalNotificationsPlugin.initialize(initializationSettings);
  }

  Future<void> _showNotification(String title, String body) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'sensor_channel', // Ensure unique ID
      'Sensor Notifications', // Human-readable name
      channelDescription: 'Notification channel for sensor data alerts',
      importance: Importance.max,
      priority: Priority.high,
    );
    const NotificationDetails platformDetails = NotificationDetails(android: androidDetails);
    await flutterLocalNotificationsPlugin.show(
      0, // Notification ID
      title,
      body,
      platformDetails,
    );
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final DateTime now = DateTime.now();
      final double newValue = _getRandomValue();

      if (mounted) {
        setState(() {
          _chartData.add(_ChartData(now, newValue));
          if (_chartData.length > 20) {
            _chartData.removeAt(0); // Keeps the data point count constant
          }
        });
      }

      if (newValue > 80) {
        _showNotification('Alert', 'High sensor reading detected!');
      }
    });
  }

  double _getRandomValue() {
    return 50 + (50 * (1 - (DateTime.now().second / 60))).toDouble();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(10.0),
        child: Column(
          children: [
            const Text(
              'Real Time Sensor Data',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 300, // Fixed height for the chart
              child: SfCartesianChart(
                title: ChartTitle(text: 'Sensor Data Over Time'),
                legend: Legend(isVisible: false),
                primaryXAxis: DateTimeAxis(
                  title: AxisTitle(text: 'Time'),
                  autoScrollingMode: AutoScrollingMode.end,
                ),
                primaryYAxis: NumericAxis(
                  title: AxisTitle(text: 'Sensor Value'),
                  interval: 10, // Adjust interval based on data range
                ),
                series: <ChartSeries<_ChartData, DateTime>>[
                  LineSeries<_ChartData, DateTime>(
                    animationDuration: 0, // Optional: disables animation for realtime effect
                    dataSource: _chartData,
                    xValueMapper: (_ChartData data, _) => data.time,
                    yValueMapper: (_ChartData data, _) => data.y,
                    dataLabelSettings: const DataLabelSettings(isVisible: true),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChartData {
  _ChartData(this.time, this.y);

  final DateTime time;
  final double y;
}
