import 'package:flutter/material.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'package:syncfusion_flutter_gauges/gauges.dart' as gauges;
import 'package:syncfusion_flutter_charts/charts.dart' as charts;
import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class HomePage extends StatefulWidget {
  final String deviceId;
  final String deviceName;

  const HomePage({required this.deviceId, required this.deviceName});

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late MqttServerClient client;
  double temperature = 0;
  double humidity = 0;
  List<ChartData> tempData = [];
  List<ChartData> humData = [];
  final user = FirebaseAuth.instance.currentUser;
  late DatabaseReference dbRef;

  @override
  void initState() {
    super.initState();
    dbRef = FirebaseDatabase.instance.ref("devices/${user?.uid}/${widget.deviceId}");
    _loadInitialData();
    _connectToMqtt();
  }

  Future<void> _loadInitialData() async {
  final tempSnap = await dbRef.child("temp").limitToLast(10).once();
  final humSnap = await dbRef.child("humidity").limitToLast(10).once();

  if (tempSnap.snapshot.value != null) {
    final tempMap = Map<String, dynamic>.from(tempSnap.snapshot.value as Map);
    final tempList = tempMap.entries.map((e) {
      final timestamp = int.tryParse(e.key);
      final time = DateTime.fromMillisecondsSinceEpoch(timestamp ?? 0);
      return ChartData(time, double.tryParse(e.value.toString()) ?? 0);
    }).toList();
    tempList.sort((a, b) => a.time.compareTo(b.time));
    setState(() {
      tempData = tempList;
      temperature = tempList.last.value;
    });
  }

  if (humSnap.snapshot.value != null) {
    final humMap = Map<String, dynamic>.from(humSnap.snapshot.value as Map);
    final humList = humMap.entries.map((e) {
      final timestamp = int.tryParse(e.key);
      final time = DateTime.fromMillisecondsSinceEpoch(timestamp ?? 0);
      return ChartData(time, double.tryParse(e.value.toString()) ?? 0);
    }).toList();
    humList.sort((a, b) => a.time.compareTo(b.time));
    setState(() {
      humData = humList;
      humidity = humList.last.value;
    });
  }
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

    client.updates?.listen((List<MqttReceivedMessage<MqttMessage?>>? c) async {
  if (!mounted || c == null || c.isEmpty) return;

  final MqttPublishMessage recMess = c[0].payload as MqttPublishMessage;
  final String payload = MqttPublishPayload.bytesToStringAsString(recMess.payload.message);
  final parts = payload.split(',');

  if (parts.length == 2) {
    final now = DateTime.now();
    final timestamp = now.millisecondsSinceEpoch.toString();
    final temp = double.tryParse(parts[0]) ?? 0;
    final hum = double.tryParse(parts[1]) ?? 0;

    if (!mounted) return;

    // Append to in-memory lists
    tempData.add(ChartData(now, temp));
    if (tempData.length > 10) tempData.removeAt(0);

    humData.add(ChartData(now, hum));
    if (humData.length > 10) humData.removeAt(0);

    // Now batch update chart state once
    if (!mounted) return;
    setState(() {
    temperature = temp;
    humidity = hum;
    tempData = List.from(tempData);
    humData = List.from(humData);
    });

    // Store in Firebase
    await dbRef.child("temp/$timestamp").set(temp);
    await dbRef.child("humidity/$timestamp").set(hum);

    // Prune Firebase temp if more than 10
    final tempSnap = await dbRef.child("temp").once();
    final tempMap = Map<String, dynamic>.from(tempSnap.snapshot.value as Map);
    if (tempMap.length > 10) {
      final oldestKey = tempMap.keys.map((k) => int.tryParse(k) ?? 0).toList()..sort();
      await dbRef.child("temp/${oldestKey.first}").remove();
    }

    // Prune Firebase humidity if more than 10
    final humSnap = await dbRef.child("humidity").once();
    final humMap = Map<String, dynamic>.from(humSnap.snapshot.value as Map);
    if (humMap.length > 10) {
      final oldestKey = humMap.keys.map((k) => int.tryParse(k) ?? 0).toList()..sort();
      await dbRef.child("humidity/${oldestKey.first}").remove();
    }
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

  Widget _buildChart(String title, List<ChartData> data, String unit, VoidCallback onExport) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            IconButton(
              icon: Icon(Icons.download_rounded, color: Colors.blue),
              onPressed: onExport,
              tooltip: 'Export CSV',
            )
          ],
        ),
      ),
      SizedBox(
        height: 200,
        child: charts.SfCartesianChart(
          primaryXAxis: charts.DateTimeAxis(),
          series: <charts.CartesianSeries<ChartData, DateTime>>[
            charts.LineSeries<ChartData, DateTime>(
              dataSource: data,
              xValueMapper: (ChartData d, _) => d.time,
              yValueMapper: (ChartData d, _) => d.value,
              name: unit,
              dataLabelSettings: charts.DataLabelSettings(isVisible: false),
            )
          ],
        ),
      ),
    ],
  );
}

Future<void> _exportToCSV(List<ChartData> dataList, String fileName) async {
  final buffer = StringBuffer();
  buffer.writeln('Timestamp,Value');

  for (var entry in dataList) {
    buffer.writeln('${entry.time.toIso8601String()},${entry.value}');
  }

  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/$fileName.csv');
  await file.writeAsString(buffer.toString());

  await Share.shareXFiles([XFile(file.path)], text: 'Exported $fileName data');
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
          _buildChart('Temperature Trend', tempData, '°C', () => _exportToCSV(tempData, 'temperature')),
          SizedBox(height: 16),
          _buildChart('Humidity Trend', humData, '%', () => _exportToCSV(humData, 'humidity')),
          SizedBox(height: 40),
        ],
      ),
    ),
  );
}


  @override
  void dispose() {
    client.disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.deviceName)),
      body: _buildHomePage(),
    );
  }
}

class ChartData {
  final DateTime time;
  final double value;
  ChartData(this.time, this.value);
}
