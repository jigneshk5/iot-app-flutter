import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:app_settings/app_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'home_page.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:open_settings_plus/open_settings_plus.dart';
import 'package:wifi_scan/wifi_scan.dart';
import 'profile.dart';

class DevicesPage extends StatefulWidget {
  @override
  _DevicesPageState createState() => _DevicesPageState();
}

class _DevicesPageState extends State<DevicesPage> {
  final user = FirebaseAuth.instance.currentUser;
  late DatabaseReference dbRef;
  List<Map<String, dynamic>> devices = [];
  int _selectedIndex = 0;

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  void initState() {
    super.initState();
    dbRef = FirebaseDatabase.instance.ref("devices/${user?.uid}");
    fetchDevices2();
  }
  void fetchDevices2() {
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
    } else {
      setState(() => devices = []);
    }
  });
}

  Future<void> _refreshDevices() async {
    await fetchDevices();
   }

  Future<void> fetchDevices() async {
  final snapshot = await dbRef.get();
  final data = snapshot.value as Map<dynamic, dynamic>?;

  if (data != null) {
    final loadedDevices = data.entries.map((e) {
      return {
        'id': e.key,
        'name': e.value['name'] ?? '',
      };
    }).toList();
    setState(() => devices = loadedDevices);
  } else {
    setState(() => devices = []);
  }
}

  void startProvisioningFlow() async {
    final selected = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => WifiProvisionStep1(userId: user?.uid ?? "")),
    );
    if (selected == true) {
      await fetchDevices();
    }
  }

  void _editDevice(Map<String, dynamic> device) async {
  final controller = TextEditingController(text: device['name']);
  await showDialog(
    context: context,
    builder: (_) => AlertDialog(
      title: Text("Edit Device Name"),
      content: TextField(
        controller: controller,
        decoration: InputDecoration(labelText: "Device Name"),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text("Cancel")),
        ElevatedButton(
          onPressed: () async {
            await dbRef.child(device['id']).update({'name': controller.text.trim()});
            Navigator.pop(context);
            await fetchDevices();
          },
          child: Text("Save"),
        ),
      ],
    ),
  );
}

void _confirmDelete(String deviceId) {
  showDialog(
    context: context,
    builder: (_) => AlertDialog(
      title: Text("Delete Device"),
      content: Text("Are you sure you want to delete this device?"),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text("Cancel")),
        ElevatedButton(
          onPressed: () async {
            await dbRef.child(deviceId).remove();
            Navigator.pop(context);
            await fetchDevices();
          },
          child: Text("Delete"),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
        ),
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
        appBar: _selectedIndex == 0?AppBar(title: Text("Devices")): AppBar(title: Text("Profile")),
        body: RefreshIndicator(
        onRefresh: _refreshDevices,
        child: _selectedIndex == 0
            ? (devices.isEmpty
                ? Center(
                    child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                        Icon(Icons.devices, size: 80, color: Colors.grey),
                        SizedBox(height: 16),
                        Text("No devices found", style: TextStyle(fontSize: 18, color: Colors.grey)),
                        ],
                    ),
                    )
                : ListView.builder(
                    itemCount: devices.length,
                    itemBuilder: (_, index) {
                        final device = devices[index];
                        return Card(
                        margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: ListTile(
                            leading: Icon(Icons.thermostat, color: Colors.blue),
                            title: Text(device['name'] ?? 'Unnamed'),
                            trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                                IconButton(
                                icon: Icon(Icons.edit, color: Colors.orange),
                                onPressed: () => _editDevice(device),
                                ),
                                IconButton(
                                icon: Icon(Icons.delete, color: Colors.red),
                                onPressed: () => _confirmDelete(device['id']),
                                ),
                            ],
                            ),
                            onTap: () {
                            Navigator.push(
                                context,
                                MaterialPageRoute(
                                builder: (_) => HomePage(
                                    deviceId: device['id'],
                                    deviceName: device['name'],
                                ),
                                ),
                            );
                            },
                        ),
                        );
                    },
                    ))
            : _buildProfilePage(),
        ),
        floatingActionButton: _selectedIndex == 0 ?FloatingActionButton(
        child: Icon(Icons.add),
        onPressed: startProvisioningFlow,
        ): null,
        bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
            BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
            BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
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
  bool _polling = false; // Add this as a class-level variable

  @override
  void initState() {
    super.initState();
    Future.delayed(Duration.zero, () {
      checkWifiConnection();
      loadSavedCredentials();
    });
  }

  void checkWifiConnection() {
  // Prevent showing multiple dialogs
  if (_polling) return;

  _polling = true;

  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => AlertDialog(
      title: Text("Connect to ThermoSensor WiFi"),
      content: Text(
        "Please connect to the device's Wi-Fi hotspot that starts with 'ThermoSensor' before continuing.",
      ),
      actions: [
        TextButton(
          onPressed: () {
            final settings = OpenSettingsPlus.shared;
            if (settings is OpenSettingsPlusAndroid) {
              settings.wifi();
            } else if (settings is OpenSettingsPlusIOS) {
              settings.wifi();
            }
          },
          child: Text("Open WiFi Settings"),
        )
      ],
    ),
  );

  _startWifiPolling(); // Only start once
}

void _startWifiPolling() async {
  final wifiName = (await NetworkInfo().getWifiName())?.replaceAll('"', '');
  if (wifiName != null && wifiName.startsWith("ThermoSensor")) {
    if (Navigator.canPop(context)) {
      Navigator.of(context, rootNavigator: true).pop(); // Close the dialog
    }
    _polling = false; // Reset flag
    return;
  }

  await Future.delayed(Duration(seconds: 2));
  if (_polling) _startWifiPolling(); // Continue polling only if still active
}

  void loadSavedCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    final ssid = prefs.getString('last_ssid') ?? '';
    final password = prefs.getString('last_password') ?? '';
    ssidController.text = ssid;
    passwordController.text = password;
  }

  void saveCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('last_ssid', ssidController.text.trim());
    await prefs.setString('last_password', passwordController.text.trim());
  }

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
        saveCredentials();
        final responseData = jsonDecode(response.body);
        final deviceId = responseData['deviceId'];

        final dbRef = FirebaseDatabase.instance.ref("devices/${widget.userId}/$deviceId");
        await dbRef.set({
            'name': "ThermoSensor"
        });

        Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => WifiProvisionStep3(userId: widget.userId, deviceId: deviceId)),
        );
    } else {
      setState(() => loading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Provisioning failed")));
    }
  }

  void showSsidOptions() async {
  final can = await WiFiScan.instance.canStartScan();
  if (can != CanStartScan.yes) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Wi-Fi scan not permitted: $can")));
    return;
  }

  await WiFiScan.instance.startScan();
  final results = await WiFiScan.instance.getScannedResults();

  final ssids = results.map((e) => e.ssid).toSet().where((e) => e.isNotEmpty).toList();

  if (ssids.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("No Wi-Fi networks found")));
    return;
  }

  final selected = await showDialog<String>(
    context: context,
    builder: (_) => SimpleDialog(
      title: Text("Choose Network"),
      children: ssids
          .map((ssid) => SimpleDialogOption(
                child: Text(ssid),
                onPressed: () => Navigator.pop(context, ssid),
              ))
          .toList(),
    ),
  );

  if (selected != null) {
    ssidController.text = selected;
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
            GestureDetector(
              onTap: showSsidOptions,
              child: AbsorbPointer(
                child: TextField(
                  controller: ssidController,
                  decoration: InputDecoration(labelText: 'Wi-Fi Name'),
                ),
              ),
            ),
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
  final String deviceId;
  WifiProvisionStep3({required this.userId, required this.deviceId});

  @override
  _WifiProvisionStep3State createState() => _WifiProvisionStep3State();
}

class _WifiProvisionStep3State extends State<WifiProvisionStep3> {
  final nameController = TextEditingController();

  void saveDevice() async {
    final dbRef = FirebaseDatabase.instance
        .ref("devices/${widget.userId}/${widget.deviceId}");
    await dbRef.update({
        'name': nameController.text.trim(),
    });
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Name Device")),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(controller: nameController, decoration: InputDecoration(labelText: "Device Name")),
            SizedBox(height: 20),
            ElevatedButton(onPressed: saveDevice, child: Text("Save")),
          ],
        ),
      ),
    );
  }
}