import 'package:flutter/material.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'package:syncfusion_flutter_gauges/gauges.dart' as gauges;
import 'package:syncfusion_flutter_charts/charts.dart';
import 'dart:async';

class HomePage extends StatefulWidget {
  final String deviceId;
  final String deviceName;

  const HomePage({required this.deviceId, required this.deviceName});

  @override
  _HomePageState createState() => _HomePageState();
}

class ChartData {
  final DateTime time;
  final double value;
  ChartData(this.time, this.value);
}

class _HomePageState extends State<HomePage> {
  late MqttServerClient client;
  double temperature = 0;
  double humidity = 0;
  List<ChartData> tempData = [];
  List<ChartData> humData = [];
  late Timer _timer;
    StreamSubscription? mqttSubscription;
bool _isMounted = true;

  @override
  void initState() {
    super.initState();
    _connectToMqtt();
  }

  @override
void dispose() {
  _isMounted = false;
  mqttSubscription?.cancel();
  client.disconnect();
  super.dispose();
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

    mqttSubscription = client.updates?.listen((List<MqttReceivedMessage<MqttMessage?>>? c) {
        if (!mounted || c == null || c.isEmpty) return;

        final MqttPublishMessage recMess = c[0].payload as MqttPublishMessage;
        final String payload = MqttPublishPayload.bytesToStringAsString(recMess.payload.message);
        final parts = payload.split(',');

        if (parts.length == 2) {
            final now = DateTime.now();
            final temp = double.tryParse(parts[0]) ?? 0;
            final hum = double.tryParse(parts[1]) ?? 0;

            if (!mounted) return;
            setState(() {
            temperature = temp;
            tempData.add(ChartData(now, temp));
            });

            if (!mounted) return;
            setState(() {
            humidity = hum;
            humData.add(ChartData(now, hum));
            });
        }
        });

  }

  void _onConnected() {
    client.subscribe('${widget.deviceId}/data', MqttQos.atMostOnce);
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

Widget _buildGauge(String label, double value, String unit) {
  return Expanded(
    child: Column(
      children: [
        Text(label, style: TextStyle(fontSize: 16)),
        SizedBox(
          height: 120,
          child: gauges.SfRadialGauge(
            axes: <gauges.RadialAxis>[
              gauges.RadialAxis(
                minimum: 0,
                maximum: 100,
                showTicks: false,
                showLabels: false,
                axisLineStyle: gauges.AxisLineStyle(
                  thickness: 0.15,
                  cornerStyle: gauges.CornerStyle.bothFlat,
                  thicknessUnit: gauges.GaugeSizeUnit.factor,
                ),
                pointers: <gauges.GaugePointer>[
                  gauges.RangePointer(
                    value: value,
                    width: 0.15,
                    color: Colors.blue,
                    cornerStyle: gauges.CornerStyle.bothCurve,
                    sizeUnit: gauges.GaugeSizeUnit.factor,
                  ),
                ],
                annotations: <gauges.GaugeAnnotation>[
                  gauges.GaugeAnnotation(
                    widget: Text('$value $unit', style: TextStyle(fontSize: 12)),
                    angle: 90,
                    positionFactor: 0.0,
                  ),
                ],
              )
            ],
          ),
        )
      ],
    ),
  );
}



  Widget _buildChart(String title, List<ChartData> data, String unit) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ),
        SizedBox(
          height: 200,
          child: SfCartesianChart(
            primaryXAxis: DateTimeAxis(),
            series: <CartesianSeries<dynamic, dynamic>>[
                LineSeries<ChartData, DateTime>(
                dataSource: data,
                xValueMapper: (ChartData d, _) => d.time,
                yValueMapper: (ChartData d, _) => d.value,
                name: unit,
                dataLabelSettings: DataLabelSettings(isVisible: false),
                )
            ],
            )
        ),
      ],
    );
  }

  Widget _buildHomePage() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
            Row(
              children: [
                _buildGauge('Temp', temperature, '°C'),
                SizedBox(width: 8),
                _buildGauge('Humidity', humidity, '%'),
              ],
            ),
            SizedBox(height: 16),
            _buildChart('Temperature Trend', tempData, '°C'),
            SizedBox(height: 16),
            _buildChart('Humidity Trend', humData, '%'),
            SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.deviceName)),
      body: _buildHomePage(),
    );
  }
}
