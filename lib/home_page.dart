import 'package:flutter/material.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'package:syncfusion_flutter_gauges/gauges.dart';
import 'profile.dart';

class HomePage extends StatefulWidget {
  final String deviceId;

  HomePage({required this.deviceId});

  @override
  _HomePageState createState() => _HomePageState();
}


class _HomePageState extends State<HomePage> {
  late MqttServerClient client;
  double temperature = 0;
  double humidity = 0;
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    print('Connected to device ID: ${widget.deviceId}');
    _connectToMqtt();
  }

  void _connectToMqtt() async {
    client = MqttServerClient('broker.hivemq.com', 'flutter_hygrometer_${DateTime.now().millisecondsSinceEpoch}');
    client.logging(on: false);
    client.keepAlivePeriod = 20;
    client.onConnected = _onConnected;
    client.onDisconnected = _onDisconnected;
    client.onSubscribed = _onSubscribed;
    client.onSubscribeFail = _onSubscribeFail;

    try {
      await client.connect();
    } catch (e) {
      print('Connection failed: $e');
      client.disconnect();
      return;
    }

    client.updates?.listen((List<MqttReceivedMessage<MqttMessage?>>? c) {
      if (c != null && c.isNotEmpty) {
        final MqttPublishMessage recMess = c[0].payload as MqttPublishMessage;
        final String payload = MqttPublishPayload.bytesToStringAsString(recMess.payload.message);
        final parts = payload.split(',');
        if (parts.length == 2) {
          setState(() {
            temperature = double.tryParse(parts[0]) ?? 0;
            humidity = double.tryParse(parts[1]) ?? 0;
          });
        }
      }
    });
  }

  void _onConnected() {
    print('Connected');
    client.subscribe('sensor/hygrometer/data', MqttQos.atMostOnce);
  }

  void _onDisconnected() {
    print('Disconnected');
  }

  void _onSubscribed(String topic) {
    print('Subscribed to $topic');
  }

  void _onSubscribeFail(String topic) {
    print('Failed to subscribe $topic');
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  Widget _buildHomePage() {
  return SingleChildScrollView(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(height: 20),
        Text('Temperature', style: TextStyle(fontSize: 20)),
        SfRadialGauge(
          axes: <RadialAxis>[
            RadialAxis(
              minimum: 0,
              maximum: 100,
              pointers: <GaugePointer>[NeedlePointer(value: temperature)],
              annotations: <GaugeAnnotation>[
                GaugeAnnotation(
                  widget: Text('$temperature °C', style: TextStyle(fontSize: 16)),
                  angle: 90,
                  positionFactor: 0.5,
                )
              ],
            )
          ],
        ),
        SizedBox(height: 20),
        Text('Humidity', style: TextStyle(fontSize: 20)),
        SfRadialGauge(
          axes: <RadialAxis>[
            RadialAxis(
              minimum: 0,
              maximum: 100,
              pointers: <GaugePointer>[NeedlePointer(value: humidity)],
              annotations: <GaugeAnnotation>[
                GaugeAnnotation(
                  widget: Text('$humidity %', style: TextStyle(fontSize: 16)),
                  angle: 90,
                  positionFactor: 0.5,
                )
              ],
            )
          ],
        ),
        SizedBox(height: 80), // add space so content doesn't get hidden behind bottom nav
      ],
    ),
  );
}


  Widget _buildProfilePage() {
    return ProfilePage(); // must be implemented in profile.dart
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('WiFi Hygrometer')),
      body: Center(
        child: _selectedIndex == 0 ? _buildHomePage() : _buildProfilePage(),
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(icon: Icon(Icons.thermostat), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
      ),
    );
  }
}
