import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:path_provider/path_provider.dart';

import '../services/bonsoir_service.dart';

class DeviceScreen extends StatefulWidget {
  final DiscoveredDevice device;

  const DeviceScreen({super.key, required this.device});

  @override
  State<DeviceScreen> createState() => _DeviceScreenState();
}

class _DeviceScreenState extends State<DeviceScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> _remoteFiles = [];
  bool _isLoadingFiles = false;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchRemoteFiles();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchRemoteFiles() async {
    if (!mounted) return;
    setState(() => _isLoadingFiles = true);

    try {
      final response = await http
          .get(
            Uri.parse(
              'http://${widget.device.ip}:${widget.device.port}/api/files',
            ),
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        setState(() {
          _remoteFiles = data.cast<Map<String, dynamic>>();
        });
      } else {
        _showSnackBar('Failed to load files: ${response.statusCode}');
      }
    } catch (e) {
      _showSnackBar('Error connecting to device: $e');
    } finally {
      if (mounted) setState(() => _isLoadingFiles = false);
    }
  }

  Future<void> _downloadFile(String fileName) async {
    try {
      // Request storage permission if needed (mostly for Android < 10 or shared storage,
      // but strictly app docs don't need it. We'll save to App Docs for now).

      final saveDir = await getApplicationDocumentsDirectory();
      final downloadsDir = Directory('${saveDir.path}/downloads');
      if (!downloadsDir.existsSync()) {
        downloadsDir.createSync();
      }

      final savePath = '${downloadsDir.path}/$fileName';

      _showSnackBar('Downloading $fileName...');

      final response = await http.get(
        Uri.parse(
          'http://${widget.device.ip}:${widget.device.port}/download/$fileName',
        ),
      );

      if (response.statusCode == 200) {
        final file = File(savePath);
        await file.writeAsBytes(response.bodyBytes);
        _showSnackBar('Downloaded to $savePath');
      } else {
        _showSnackBar('Download failed: ${response.statusCode}');
      }
    } catch (e) {
      _showSnackBar('Download error: $e');
    }
  }

  Future<void> _sendFile() async {
    final result = await FilePicker.platform.pickFiles();
    if (result != null && result.files.single.path != null) {
      setState(() => _isUploading = true);
      final file = File(result.files.single.path!);

      final request = http.MultipartRequest(
        'POST',
        Uri.parse('http://${widget.device.ip}:${widget.device.port}/upload'),
      );

      request.files.add(await http.MultipartFile.fromPath('file', file.path));

      try {
        final response = await request.send();
        if (response.statusCode == 200) {
          _showSnackBar('File sent successfully!');
          // Refresh remote files if we want to see it?
          // Usually uploaded files show up on their list.
          _fetchRemoteFiles();
        } else {
          _showSnackBar('Failed to send: ${response.statusCode}');
        }
      } catch (e) {
        _showSnackBar('Error sending file: $e');
      } finally {
        if (mounted) setState(() => _isUploading = false);
      }
    }
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.device.name),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Browse Files', icon: Icon(Icons.folder_open)),
            Tab(text: 'Send File', icon: Icon(Icons.upload_file)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Browse Tab
          _isLoadingFiles
              ? const Center(child: CircularProgressIndicator())
              : _remoteFiles.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('No files found on this device.'),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _fetchRemoteFiles,
                        child: const Text('Refresh'),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _fetchRemoteFiles,
                  child: ListView.separated(
                    itemCount: _remoteFiles.length,
                    separatorBuilder: (context, index) => const Divider(),
                    itemBuilder: (context, index) {
                      final file = _remoteFiles[index];
                      final name = file['name'] ?? 'Unknown';
                      final size = file['size'] ?? 0;
                      return ListTile(
                        leading: const Icon(Icons.insert_drive_file),
                        title: Text(name),
                        subtitle: Text(
                          '${(size / 1024 / 1024).toStringAsFixed(2)} MB',
                        ),
                        trailing: IconButton(
                          icon: const Icon(
                            Icons.download_rounded,
                            color: Colors.blue,
                          ),
                          onPressed: () => _downloadFile(name),
                        ),
                      );
                    },
                  ),
                ),

          // Send Tab
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.upload, size: 64, color: Colors.blue),
                const SizedBox(height: 24),
                const Text(
                  'Send a file to this device',
                  style: TextStyle(fontSize: 18),
                ),
                const SizedBox(height: 24),
                _isUploading
                    ? const CircularProgressIndicator()
                    : ElevatedButton.icon(
                        onPressed: _sendFile,
                        icon: const Icon(Icons.add),
                        label: const Text('Pick File to Send'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 32,
                            vertical: 16,
                          ),
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
