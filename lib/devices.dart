import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'home_page.dart';

class DevicesPage extends StatefulWidget {
  @override
  _DevicesPageState createState() => _DevicesPageState();
}

class _DevicesPageState extends State<DevicesPage> {
  final user = FirebaseAuth.instance.currentUser;
  late DatabaseReference dbRef;
  List<Map<String, dynamic>> devices = [];
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    dbRef = FirebaseDatabase.instance.ref("devices/${user?.uid}");
    fetchDevices();
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  void fetchDevices() {
    dbRef.onValue.listen((event) {
      final data = event.snapshot.value as Map<dynamic, dynamic>?;
      if (data != null) {
        final loadedDevices = data.entries.map((e) {
          return {
            'id': e.key,
            'name': e.value['name'] ?? '',
          };
        }).toList();
        setState(() => devices = loadedDevices);
      }
    });
  }

  void startProvisioningFlow() async {
    final selected = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => WifiProvisionStep1(userId: user?.uid ?? "")),
    );
    if (selected == true) {
      fetchDevices();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Devices")),
      body: ListView.builder(
        itemCount: devices.length,
        itemBuilder: (_, index) {
          final device = devices[index];
          return ListTile(
            title: Text(device['name'] ?? 'Unnamed'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => HomePage(deviceId: device['id'])),
              );
            },
          );
        },
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(icon: Icon(Icons.thermostat), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
      ),
      floatingActionButton: FloatingActionButton(
        child: Icon(Icons.add),
        onPressed: startProvisioningFlow,
      ),
    );
  }
}

class WifiProvisionStep1 extends StatefulWidget {
  final String userId;
  WifiProvisionStep1({required this.userId});

  @override
  _WifiProvisionStep1State createState() => _WifiProvisionStep1State();
}

class _WifiProvisionStep1State extends State<WifiProvisionStep1> {
  final ssidController = TextEditingController();
  final passwordController = TextEditingController();
  bool loading = false;

  void handleNext() async {
    setState(() => loading = true);
    final response = await http.post(
      Uri.parse('http://192.168.4.1/provision'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'ssid': ssidController.text.trim(),
        'password': passwordController.text.trim(),
      }),
    );

    if (response.statusCode == 200) {
      final dbRef = FirebaseDatabase.instance.ref("devices/${widget.userId}");
      final newDeviceRef = dbRef.push();
      await newDeviceRef.set({
        'name': 'Unnamed',
        'provisioned': true,
        'ssid': ssidController.text.trim()
      });
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => WifiProvisionStep3(userId: widget.userId)),
      );
    } else {
      setState(() => loading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Provisioning failed")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Choose Network")),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(controller: ssidController, decoration: InputDecoration(labelText: 'Wi-Fi Name')),
            TextField(controller: passwordController, decoration: InputDecoration(labelText: 'Password'), obscureText: true),
            SizedBox(height: 20),
            loading
                ? CircularProgressIndicator()
                : ElevatedButton(
                    onPressed: handleNext,
                    child: Text("Connect"),
                  )
          ],
        ),
      ),
    );
  }
}

class WifiProvisionStep3 extends StatefulWidget {
  final String userId;
  WifiProvisionStep3({required this.userId});

  @override
  _WifiProvisionStep3State createState() => _WifiProvisionStep3State();
}

class _WifiProvisionStep3State extends State<WifiProvisionStep3> {
  final nameController = TextEditingController();

  void saveDevice() async {
    final dbRef = FirebaseDatabase.instance.ref("devices/${widget.userId}");
    final newRef = dbRef.push();
    await newRef.set({
      'name': nameController.text.trim(),
    });
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Name your Device")),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(controller: nameController, decoration: InputDecoration(labelText: "Device Name")),
            SizedBox(height: 20),
            ElevatedButton(onPressed: saveDevice, child: Text("Save")),
          ],
        ),
      )
    );
  }
}
