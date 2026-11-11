import 'dart:async';
import 'package:flutter/material.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:ping_discover_network_fork/ping_discover_network_fork.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  runApp(const AliBakarNetworkApp());
}

class AliBakarNetworkApp extends StatelessWidget {
  const AliBakarNetworkApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'فاحص الشبكة - علي بكر',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.deepPurple,
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFF121212),
        colorScheme: const ColorScheme.dark(
          primary: Colors.deepPurpleAccent,
          surface: Color(0xFF1E1E2C),
        ),
      ),
      home: const NetworkScannerScreen(),
    );
  }
}

class NetworkDevice {
  final String ip;
  bool isOnline;
  final String deviceType;

  NetworkDevice({
    required this.ip,
    required this.isOnline,
    required this.deviceType,
  });
}

class NetworkScannerScreen extends StatefulWidget {
  const NetworkScannerScreen({super.key});

  @override
  State<NetworkScannerScreen> createState() => _NetworkScannerScreenState();
}

class _NetworkScannerScreenState extends State<NetworkScannerScreen> {
  final List<NetworkDevice> _devices = [];
  bool _isScanning = false;
  String _localIP = 'غير معروف';
  String _subnet = '';
  int _foundCount = 0;

  @override
  void initState() {
    super.initState();
    _requestPermissions();
  }

  Future<void> _requestPermissions() async {
    await [
      Permission.location,
      Permission.nearbyWifiDevices,
    ].request();
    _getNetworkDetails();
  }

  Future<void> _getNetworkDetails() async {
    final info = NetworkInfo();
    String? ip = await info.getWifiIP();
    if (ip != null && ip.contains('.')) {
      setState(() {
        _localIP = ip;
        _subnet = ip.substring(0, ip.lastIndexOf('.'));
      });
    }
  }

  void _startScan() async {
    if (_subnet.isEmpty) {
      await _getNetworkDetails();
      if (_subnet.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('يرجى الاتصال بشبكة Wi-Fi أولاً')),
        );
        return;
      }
    }

    setState(() {
      _isScanning = true;
      _devices.clear();
      _foundCount = 0;
    });

    const int port = 80;
    final stream = NetworkAnalyzer.discover2(_subnet, port, timeout: const Duration(milliseconds: 500));

    stream.listen((NetworkAddress addr) {
      if (addr.exists) {
        setState(() {
          _foundCount++;
          String type = "جهاز فرعي";
          if (addr.ip.endsWith('.1')) {
            type = "الراوتر الرئيسي";
          } else if (addr.ip == _localIP) {
            type = "هذا الهاتف";
          }
          _devices.add(NetworkDevice(
            ip: addr.ip,
            isOnline: true,
            deviceType: type,
          ));
        });
      }
    }, onDone: () {
      setState(() {
        _isScanning = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('فاحص الشبكة - علي بكر'),
        centerTitle: true,
        backgroundColor: Colors.deepPurple.shade900,
      ),
      body: Stack(
        children: [
          // علامة مائية وشعار باسم [علي بكر] في الخلفية
          Center(
            child: Opacity(
              opacity: 0.05,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.wifi_tethering, size: 180, color: Colors.white),
                  SizedBox(height: 20),
                  Text(
                    'على بكر',
                    style: TextStyle(
                      fontSize: 60,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    'Ali Bakar Network Tool',
                    style: TextStyle(fontSize: 20, color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
          
          // المحتوى الرئيسي
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Card(
                  color: const Color(0xFF2A2A3D),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('IP الهاتف الحالي:', style: TextStyle(color: Colors.grey)),
                            Text(_localIP, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.greenAccent)),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            const Text('الأجهزة المكتشفة:', style: TextStyle(color: Colors.grey)),
                            Text('$_foundCount', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.deepPurpleAccent)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurpleAccent,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: _isScanning ? null : _startScan,
                    icon: _isScanning
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.search, color: Colors.white),
                    label: Text(
                      _isScanning ? 'جاري فحص IPs الشبكة...' : 'بدء فحص الأجهزة',
                      style: const TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                
                Expanded(
                  child: _devices.isEmpty
                      ? Center(
                          child: Text(
                            _isScanning ? 'جاري البحث عن الأجهزة...' : 'اضغط على زر الفحص للبدء',
                            style: const TextStyle(color: Colors.grey),
                          ),
                        )
                      : ListView.builder(
                          itemCount: _devices.length,
                          itemBuilder: (context, index) {
                            final device = _devices[index];
                            return Card(
                              color: const Color(0xFF1E1E2C),
                              margin: const EdgeInsets.symmetric(vertical: 6),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: device.isOnline ? Colors.green.withOpacity(0.2) : Colors.red.withOpacity(0.2),
                                  child: Icon(
                                    device.deviceType == "الراوتر الرئيسي" ? Icons.router : Icons.devices,
                                    color: device.isOnline ? Colors.greenAccent : Colors.redAccent,
                                  ),
                                ),
                                title: Text(device.ip, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                                subtitle: Text(device.deviceType, style: const TextStyle(color: Colors.grey)),
                                trailing: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: device.isOnline ? Colors.green.withOpacity(0.2) : Colors.red.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: device.isOnline ? Colors.green : Colors.red),
                                  ),
                                  child: Text(
                                    device.isOnline ? 'Online' : 'Offline',
                                    style: TextStyle(color: device.isOnline ? Colors.greenAccent : Colors.redAccent, fontSize: 12),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
                
                const Padding(
                  padding: EdgeInsets.only(top: 8.0),
                  child: Text(
                    'تم التطوير بواسطة: على بكر (Ali Bakar)',
                    style: TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
