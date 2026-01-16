import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';

import '../services/server_service.dart';
import '../services/bonsoir_service.dart';
import 'device_screen.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'dart:async';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ServerService _serverService = ServerService();
  final BonsoirServiceWrapper _bonsoirService = BonsoirServiceWrapper();

  List<File> _downloadedFiles = [];
  late StreamSubscription _intentDataStreamSubscription;

  @override
  void initState() {
    super.initState();
    _startServices();
    _loadDownloadedFiles();
    _initSharingIntent();
  }

  void _initSharingIntent() {
    _intentDataStreamSubscription = ReceiveSharingIntent.instance
        .getMediaStream()
        .listen(
          (List<SharedMediaFile> value) {
            if (value.isNotEmpty) {
              for (var file in value) {
                _serverService.addFile(file.path);
              }
              _showSnackBar('Shared ${value.length} files from another app');
            }
          },
          onError: (err) {
            debugPrint("getIntentDataStream error: $err");
          },
        );

    ReceiveSharingIntent.instance.getInitialMedia().then((
      List<SharedMediaFile> value,
    ) {
      if (value.isNotEmpty) {
        for (var file in value) {
          _serverService.addFile(file.path);
        }
        _showSnackBar('Shared ${value.length} files from another app');
      }
    });
  }

  void _showSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _loadDownloadedFiles() async {
    final dir = await getApplicationDocumentsDirectory();
    final downloadsDir = Directory('${dir.path}/downloads');
    if (downloadsDir.existsSync()) {
      setState(() {
        _downloadedFiles = downloadsDir.listSync().whereType<File>().toList();
      });
    }
  }

  Future<void> _startServices() async {
    await _serverService.startServer();
    // Start broadcast and discovery
    // We need to wait for server to start to get the port
    if (_serverService.isRunning) {
      await _bonsoirService.startBroadcast(_serverService.port);
      await _bonsoirService.startDiscovery();
    }
    setState(() {}); // Rebuild to show IP/Port
  }

  Future<void> _testLocalDownload(File file) async {
    final fileName = file.uri.pathSegments.last;
    final dir = await getApplicationDocumentsDirectory();
    final downloadsDir = Directory('${dir.path}/downloads');
    if (!downloadsDir.existsSync()) {
      downloadsDir.createSync();
    }
    final savePath = '${downloadsDir.path}/$fileName';
    await file.copy(savePath);
    _loadDownloadedFiles();
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Saved a copy of $fileName')));
    }
  }

  Future<void> _showConnectDialog() async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Connect to Device'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: '192.168.1.XX:8080',
            labelText: 'Device IP and Port',
          ),
          keyboardType: TextInputType.url,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Connect'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      final parts = result.split(':');
      if (parts.length == 2) {
        final ip = parts[0];
        final port = int.tryParse(parts[1]);
        if (port != null) {
          if (!mounted) return;
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => DeviceScreen(
                device: DiscoveredDevice(
                  name: 'Manual Connection',
                  ip: ip,
                  port: port,
                  serviceName: 'manual',
                ),
              ),
            ),
          ).then((_) => _loadDownloadedFiles());
        }
      }
    }
  }

  @override
  void dispose() {
    _intentDataStreamSubscription.cancel();
    _serverService.stopServer();
    _bonsoirService.stop();
    super.dispose();
  }

  void _copyToClipboard(BuildContext context) {
    if (_serverService.ipAddress != null) {
      final address =
          'http://${_serverService.ipAddress}:${_serverService.port}';
      Clipboard.setData(ClipboardData(text: address));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Address copied to clipboard!')),
      );
    }
  }

  Future<void> _pickAndShareFile() async {
    final result = await FilePicker.platform.pickFiles();
    if (result != null && result.files.single.path != null) {
      await _serverService.addFile(result.files.single.path!);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('File shared!')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Flutter Wi-Fi Share'),
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
      ),
      body: ListenableBuilder(
        listenable: Listenable.merge([_serverService, _bonsoirService]),
        builder: (context, child) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Info Card
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        const Text(
                          'Your Device Address',
                          style: TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            InkWell(
                              onTap: () => _copyToClipboard(context),
                              borderRadius: BorderRadius.circular(8),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8.0,
                                  vertical: 4.0,
                                ),
                                child: Text(
                                  _serverService.ipAddress != null
                                      ? 'http://${_serverService.ipAddress}:${_serverService.port}'
                                      : 'Initializing...',
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue,
                                  ),
                                ),
                              ),
                            ),
                            if (_serverService.ipAddress != null)
                              IconButton(
                                icon: const Icon(
                                  Icons.copy,
                                  color: Colors.blue,
                                ),
                                onPressed: () => _copyToClipboard(context),
                                tooltip: 'Copy Address',
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Open this URL in a browser on other devices',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Pick File Button
                ElevatedButton.icon(
                  onPressed: _pickAndShareFile,
                  icon: const Icon(Icons.add),
                  label: const Text('Share a File'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    textStyle: const TextStyle(fontSize: 18),
                  ),
                ),

                const SizedBox(height: 24),

                // Manual Connect
                OutlinedButton.icon(
                  onPressed: _showConnectDialog,
                  icon: const Icon(Icons.link),
                  label: const Text('Connect to IP manually'),
                ),

                const SizedBox(height: 24),

                // Shared Files List
                const Text(
                  'Your Shared Files',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                _serverService.sharedFiles.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Text(
                          'No files shared yet.',
                          style: TextStyle(color: Colors.grey),
                        ),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _serverService.sharedFiles.length,
                        itemBuilder: (context, index) {
                          final file = _serverService.sharedFiles[index];
                          return ListTile(
                            leading: const Icon(
                              Icons.file_present,
                              color: Colors.blue,
                            ),
                            title: Text(file.uri.pathSegments.last),
                            subtitle: Text(
                              '${(file.lengthSync() / 1024 / 1024).toStringAsFixed(2)} MB',
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.save_alt),
                              onPressed: () => _testLocalDownload(file),
                              tooltip: 'Save a copy locally',
                            ),
                          );
                        },
                      ),

                const SizedBox(height: 24),

                // Downloaded Files List
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Downloaded Files',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh),
                      onPressed: _loadDownloadedFiles,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _downloadedFiles.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Text(
                          'No files downloaded yet.',
                          style: TextStyle(color: Colors.grey),
                        ),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _downloadedFiles.length,
                        itemBuilder: (context, index) {
                          final file = _downloadedFiles[index];
                          return ListTile(
                            leading: const Icon(
                              Icons.file_download_done,
                              color: Colors.green,
                            ),
                            title: Text(file.uri.pathSegments.last),
                            trailing: IconButton(
                              icon: const Icon(Icons.open_in_new),
                              onPressed: () => OpenFilex.open(file.path),
                            ),
                            onTap: () => OpenFilex.open(file.path),
                          );
                        },
                      ),

                const SizedBox(height: 24),

                // Nearby Devices List
                const Text(
                  'Nearby Devices',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                _bonsoirService.devices.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Text(
                          'No devices found.',
                          style: TextStyle(color: Colors.grey),
                        ),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _bonsoirService.devices.length,
                        itemBuilder: (context, index) {
                          final device = _bonsoirService.devices[index];
                          return Card(
                            child: ListTile(
                              leading: const Icon(
                                Icons.devices,
                                color: Colors.green,
                              ),
                              title: Text(device.name),
                              subtitle: Text('${device.ip}:${device.port}'),
                              trailing: const Icon(Icons.arrow_forward_ios),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        DeviceScreen(device: device),
                                  ),
                                ).then(
                                  (_) => _loadDownloadedFiles(),
                                ); // Refresh downloads on return
                              },
                            ),
                          );
                        },
                      ),
              ],
            ),
          );
        },
      ),
    );
  }
}
