import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  runApp(const AliBakarNetworkApp());
}

class AliBakarNetworkApp extends StatelessWidget {
  const AliBakarNetworkApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'فاحص الشبكة المتقدم - علي بكر',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.deepPurple,
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFF0F0F1A),
        colorScheme: const ColorScheme.dark(
          primary: Colors.deepPurpleAccent,
          surface: Color(0xFF1A1A2E),
        ),
      ),
      home: const NetworkScannerScreen(),
    );
  }
}

class NetworkDevice {
  final String ip;
  final String name;
  bool isOnline;
  final String deviceType;

  NetworkDevice({
    required this.ip,
    required this.name,
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
  String _localIP = 'جاري الجلب...';
  String _subnet = '';
  double _scanProgress = 0.0;
  int _foundCount = 0;

  @override
  void initState() {
    super.initState();
    _initNetwork();
  }

  Future<void> _initNetwork() async {
    await [
      Permission.location,
      Permission.nearbyWifiDevices,
    ].request();
    await _getNetworkDetails();
  }

  Future<void> _getNetworkDetails() async {
    final info = NetworkInfo();
    String? ip = await info.getWifiIP();
    if (ip != null && ip.contains('.')) {
      setState(() {
        _localIP = ip;
        _subnet = ip.substring(0, ip.lastIndexOf('.'));
      });
    } else {
      setState(() {
        _localIP = 'غير متصل بشبكة Wi-Fi';
      });
    }
  }

  void _startAdvancedScan() async {
    if (_subnet.isEmpty) {
      await _getNetworkDetails();
      if (_subnet.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('يرجى الاتصال بشبكة Wi-Fi أولاً لتنفيذ الفحص')),
        );
        return;
      }
    }

    setState(() {
      _isScanning = true;
      _devices.clear();
      _foundCount = 0;
      _scanProgress = 0.0;
    });

    List<Future<NetworkDevice?>> futures = [];

    for (int i = 1; i <= 254; i++) {
      String targetIp = '$_subnet.$i';
      futures.add(_pingAndIdentify(targetIp));
    }

    int completed = 0;
    for (var future in futures) {
      future.then((device) {
        if (mounted) {
          setState(() {
            completed++;
            _scanProgress = completed / 254;
            if (device != null) {
              _foundCount++;
              _devices.add(device);
              _devices.sort((a, b) => a.ip.compareTo(b.ip));
            }
          });
        }
      });
    }

    await Future.wait(futures);

    if (mounted) {
      setState(() {
        _isScanning = false;
      });
    }
  }

  Future<NetworkDevice?> _pingAndIdentify(String ip) async {
    try {
      final socket = await Socket.connect(ip, 80, timeout: const Duration(milliseconds: 400));
      socket.destroy();
      
      String type = "جهاز متصل";
      if (ip.endsWith('.1')) {
        type = "الراوتر الرئيسي (Gateway)";
      } else if (ip == _localIP) {
        type = "هذا الهاتف (Current Device)";
      }

      return NetworkDevice(
        ip: ip,
        name: 'جهاز نشط',
        isOnline: true,
        deviceType: type,
      );
    } catch (_) {
      try {
        final socket = await Socket.connect(ip, 443, timeout: const Duration(milliseconds: 300));
        socket.destroy();
        return NetworkDevice(
          ip: ip,
          name: 'جهاز آمن',
          isOnline: true,
          deviceType: ip == _localIP ? "هذا الهاتف" : "جهاز شبكي",
        );
      } catch (e) {
        return null;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('فاحص الشبكة - علي بكر'),
        centerTitle: true,
        backgroundColor: const Color(0xFF16162C),
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A2E),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.deepPurpleAccent.withOpacity(0.3)),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('IP الهاتف:', style: TextStyle(color: Colors.grey, fontSize: 12)),
                          const SizedBox(height: 4),
                          Text(_localIP, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.greenAccent)),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text('المكتشفة:', style: TextStyle(color: Colors.grey, fontSize: 12)),
                          const SizedBox(height: 4),
                          Text('$_foundCount جهاز', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.deepPurpleAccent)),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (_isScanning) ...[
                    LinearProgressIndicator(value: _scanProgress, color: Colors.deepPurpleAccent, backgroundColor: Colors.white10),
                    const SizedBox(height: 8),
                    Text('جاري فحص الشبكة بسرعة فائقة... ${(_scanProgress * 100).toStringAsFixed(0)}%', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  ] else ...[
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.deepPurpleAccent,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: _startAdvancedScan,
                        icon: const Icon(Icons.bolt, color: Colors.white),
                        label: const Text('بدء الفحص السريع الشامل', style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ]
                ],
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _devices.isEmpty
                  ? Center(
                      child: Text(
                        _isScanning ? 'جارٍ تحليل نطاق الشبكة...' : 'اضغط على زر الفحص لاكتشاف الأجهزة',
                        style: const TextStyle(color: Colors.grey),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _devices.length,
                      itemBuilder: (context, index) {
                        final device = _devices[index];
                        return Card(
                          color: const Color(0xFF16162C),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          margin: const EdgeInsets.symmetric(vertical: 6),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Colors.deepPurple.withOpacity(0.2),
                              child: Icon(
                                device.deviceType.contains("الراوتر") ? Icons.router : Icons.devices_other,
                                color: Colors.deepPurpleAccent,
                              ),
                            ),
                            title: Text(device.ip, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                            subtitle: Text(device.deviceType, style: const TextStyle(color: Colors.grey, fontSize: 13)),
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.green.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.greenAccent),
                              ),
                              child: const Text('متصل', style: TextStyle(color: Colors.greenAccent, fontSize: 11)),
                            ),
                          ),
                        );
                      },
                    ),
            ),
            const Padding(
              padding: EdgeInsets.only(top: 8.0),
              child: Text(
                'تصميم وتطوير: علي بكر (Ali Bakar)',
                style: TextStyle(color: Colors.white38, fontSize: 11),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
