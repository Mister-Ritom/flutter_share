// import 'dart:convert'; // Unused
import 'package:flutter/foundation.dart';
import 'package:bonsoir/bonsoir.dart';
import 'package:device_info_plus/device_info_plus.dart';
// import 'package:bonsoir_platform_interface/bonsoir_platform_interface.dart'; // Unnecessary
// import 'package:network_info_plus/network_info_plus.dart'; // Unused

class DiscoveredDevice {
  final String name;
  final String ip;
  final int port;
  final String serviceName;

  DiscoveredDevice({
    required this.name,
    required this.ip,
    required this.port,
    required this.serviceName,
  });
}

class BonsoirServiceWrapper extends ChangeNotifier {
  BonsoirBroadcast? _broadcast;
  BonsoirDiscovery? _discovery;
  final List<DiscoveredDevice> _devices = [];

  List<DiscoveredDevice> get devices => List.unmodifiable(_devices);

  // Start broadcasting presence
  Future<void> startBroadcast(int port) async {
    String deviceName = 'FlutterShare User';

    try {
      final deviceInfo = DeviceInfoPlugin();
      if (defaultTargetPlatform == TargetPlatform.android) {
        final androidInfo = await deviceInfo.androidInfo;
        deviceName = '${androidInfo.brand} ${androidInfo.model}';
      } else if (defaultTargetPlatform == TargetPlatform.iOS) {
        final iosInfo = await deviceInfo.iosInfo;
        deviceName = iosInfo.name;
      } else if (defaultTargetPlatform == TargetPlatform.macOS) {
        final macInfo = await deviceInfo.macOsInfo;
        deviceName = macInfo.computerName;
      }
    } catch (e) {
      debugPrint('Error getting device info: $e');
    }

    final service = BonsoirService(
      name: deviceName,
      type: '_fluttershare._tcp',
      port: port,
    );

    _broadcast = BonsoirBroadcast(service: service);
    await _broadcast!.start();
    debugPrint('Bonsoir broadcast started: $deviceName');
  }

  // Start discovering other devices
  Future<void> startDiscovery() async {
    // Only clear validation/error checking logic if needed
    _devices.clear();
    notifyListeners();

    _discovery = BonsoirDiscovery(type: '_fluttershare._tcp');
    // await _discovery!.ready;
    await _discovery!.start();

    _discovery!.eventStream!.listen((event) {
      if (event is BonsoirDiscoveryServiceResolvedEvent) {
        final dynamic service = event.service;
        String? ip;
        try {
          ip = service.host;
        } catch (_) {
          try {
            ip = service.ip;
          } catch (_) {}
        }

        if (ip != null) {
          _addDevice(
            DiscoveredDevice(
              name: service.name,
              ip: ip,
              port: service.port,
              serviceName: service.name,
            ),
          );
        }
      } else if (event is BonsoirDiscoveryServiceLostEvent) {
        _removeDevice(event.service.name);
      }
    });

    debugPrint('Bonsoir discovery started');
  }

  void _addDevice(DiscoveredDevice device) {
    // Avoid duplicates
    if (!_devices.any((d) => d.name == device.name)) {
      _devices.add(device);
      notifyListeners();
    }
  }

  void _removeDevice(String name) {
    _devices.removeWhere((d) => d.name == name);
    notifyListeners();
  }

  Future<void> stop() async {
    await _broadcast?.stop();
    await _discovery?.stop();
    _broadcast = null;
    _discovery = null;
    _devices.clear();
    notifyListeners();
  }
}
