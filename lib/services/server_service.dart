import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf_multipart/shelf_multipart.dart';
import 'package:path_provider/path_provider.dart';
import 'package:network_info_plus/network_info_plus.dart';

class ServerService extends ChangeNotifier {
  HttpServer? _server;
  String? _ipAddress;
  int _port =
      0; // 0 lets system pick, but we might want fixed 8080. Let's try 8080.
  List<File> _sharedFiles = [];

  String? get ipAddress => _ipAddress;
  int get port => _port;
  bool get isRunning => _server != null;
  List<File> get sharedFiles => List.unmodifiable(_sharedFiles);

  Future<void> startServer() async {
    if (_server != null) return;

    final info = NetworkInfo();
    _ipAddress = await info.getWifiIP();

    if (_ipAddress == null) {
      debugPrint("Could not get IP address, possibly not on WiFi.");
      // Ideally show error to user, but for now just logging.
    }

    await _refreshSharedFiles();

    final router = Router();

    // Serve web assets
    router.get(
      '/',
      (Request request) => _serveAsset('assets/web/index.html', 'text/html'),
    );
    router.get(
      '/style.css',
      (Request request) => _serveAsset('assets/web/style.css', 'text/css'),
    );
    router.get(
      '/script.js',
      (Request request) =>
          _serveAsset('assets/web/script.js', 'application/javascript'),
    );

    // API: List files
    router.get('/api/files', (Request request) {
      try {
        final filesList = _sharedFiles
            .map(
              (f) => {
                'name': f.uri.pathSegments.last,
                'size': f.existsSync() ? f.lengthSync() : 0,
                'path': f.path,
              },
            )
            .toList();
        return Response.ok(
          jsonEncode(filesList),
          headers: {'content-type': 'application/json'},
        );
      } catch (e) {
        debugPrint('Error listing files: $e');
        return Response.internalServerError();
      }
    });

    // API: Download file
    router.get('/download/<name>', (Request request, String name) {
      try {
        final decodedName = Uri.decodeComponent(name);
        final file = _sharedFiles.firstWhere(
          (f) => f.uri.pathSegments.last == decodedName,
          orElse: () => File(''),
        );

        if (!file.existsSync()) {
          return Response.notFound('File not found');
        }

        return Response.ok(
          file.openRead(),
          headers: {
            'content-type': 'application/octet-stream',
            'content-disposition': 'attachment; filename="$decodedName"',
          },
        );
      } catch (e) {
        debugPrint('Error downloading file: $e');
        return Response.internalServerError();
      }
    });

    // API: Upload file
    router.post('/upload', (Request request) async {
      final formData = request.formData();
      if (formData == null) {
        return Response.badRequest(body: 'Not a multipart form request');
      }

      try {
        await for (final part in formData.parts) {
          final contentDisposition = part.headers['content-disposition'];
          final name = _parseHeaderValue(contentDisposition, 'name');
          final filename = _parseHeaderValue(contentDisposition, 'filename');

          if (name == 'file' && filename != null) {
            final dir = await getApplicationDocumentsDirectory();
            final saveDir = Directory('${dir.path}/shared_files');
            if (!saveDir.existsSync()) {
              await saveDir.create(recursive: true);
            }

            final file = File('${saveDir.path}/$filename');
            final sink = file.openWrite();
            await sink.addStream(part);
            await sink.close();
          }
        }

        await _refreshSharedFiles();
        return Response.ok('Uploaded successfully');
      } catch (e) {
        debugPrint('Upload error: $e');
        return Response.internalServerError(body: 'Upload failed: $e');
      }
    });

    final handler = Pipeline()
        .addMiddleware(logRequests())
        .addHandler(router.call);

    // Try port 8080, if busy, let system pick one.
    try {
      _server = await shelf_io.serve(handler, InternetAddress.anyIPv4, 8080);
      _port = 8080;
    } catch (e) {
      _server = await shelf_io.serve(handler, InternetAddress.anyIPv4, 0);
      _port = _server!.port;
    }

    debugPrint('Server running on $_ipAddress:$_port');
    notifyListeners();
  }

  Future<void> stopServer() async {
    await _server?.close();
    _server = null;
    notifyListeners();
  }

  Future<Response> _serveAsset(String assetPath, String contentType) async {
    try {
      final byteData = await rootBundle.load(assetPath);
      final bytes = byteData.buffer.asUint8List();
      return Response.ok(bytes, headers: {'content-type': contentType});
    } catch (e) {
      debugPrint('Error loading asset $assetPath: $e');
      return Response.internalServerError(body: 'Error loading asset');
    }
  }

  Future<void> _refreshSharedFiles() async {
    final dir = await getApplicationDocumentsDirectory();
    final saveDir = Directory('${dir.path}/shared_files');
    if (saveDir.existsSync()) {
      _sharedFiles = saveDir.listSync().whereType<File>().toList();
    } else {
      _sharedFiles = [];
    }
    notifyListeners();
  }

  Future<void> addFile(String path) async {
    final file = File(path);
    if (file.existsSync()) {
      final dir = await getApplicationDocumentsDirectory();
      final saveDir = Directory('${dir.path}/shared_files');
      if (!saveDir.existsSync()) {
        saveDir.createSync();
      }
      final newPath = '${saveDir.path}/${file.uri.pathSegments.last}';
      await file.copy(newPath);
      await _refreshSharedFiles();
    }
  }

  String? _parseHeaderValue(String? header, String key) {
    if (header == null) return null;
    final regex = RegExp('$key="([^"]+)"');
    final match = regex.firstMatch(header);
    return match?.group(1);
  }
}
