import 'dart:async';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../models/browser_models.dart';

class DownloadService {
  final _clients = <String, HttpClient>{};

  Future<DownloadEntry> createEntry({
    required String id,
    required String url,
    required String fileName,
    required String mimeType,
    required int totalBytes,
  }) async {
    final root = await getApplicationDocumentsDirectory();
    final directory = Directory('${root.path}/roam_downloads');
    await directory.create(recursive: true);
    final safeName = sanitizeFileName(fileName);
    final path = await _uniquePath(directory, safeName);
    return DownloadEntry(
      id: id,
      fileName: path.split(Platform.pathSeparator).last,
      url: url,
      path: path,
      mimeType: mimeType,
      createdAt: DateTime.now(),
      totalBytes: totalBytes,
    );
  }

  Future<void> download(
    DownloadEntry entry, {
    String? userAgent,
    required void Function() onUpdate,
  }) async {
    final client = HttpClient()..autoUncompress = true;
    _clients[entry.id] = client;
    final file = File(entry.path);
    IOSink? sink;
    try {
      final request = await client.getUrl(Uri.parse(entry.url));
      request.followRedirects = true;
      request.maxRedirects = 8;
      if (userAgent != null && userAgent.isNotEmpty) {
        request.headers.set(HttpHeaders.userAgentHeader, userAgent);
      }
      final response = await request.close();
      if (response.statusCode < 200 || response.statusCode >= 400) {
        throw HttpException('HTTP ${response.statusCode}', uri: request.uri);
      }
      if (response.contentLength > 0) {
        entry.totalBytes = response.contentLength;
      }
      sink = file.openWrite();
      var lastReported = 0;
      await for (final chunk in response) {
        sink.add(chunk);
        entry.receivedBytes += chunk.length;
        if (entry.receivedBytes - lastReported >= 256 * 1024) {
          lastReported = entry.receivedBytes;
          onUpdate();
        }
      }
      await sink.flush();
      entry.status = DownloadStatus.complete;
      entry.error = null;
    } catch (error) {
      if (entry.status != DownloadStatus.cancelled) {
        entry.status = DownloadStatus.failed;
        entry.error = error.toString();
      }
      if (entry.status != DownloadStatus.complete && await file.exists()) {
        await file.delete();
      }
    } finally {
      await sink?.close();
      client.close(force: true);
      _clients.remove(entry.id);
      onUpdate();
    }
  }

  void cancel(String id) {
    _clients.remove(id)?.close(force: true);
  }

  static String sanitizeFileName(String value) {
    final cleaned = value
        .replaceAll(RegExp(r'[\\/:*?"<>|\x00-\x1F]'), '_')
        .trim();
    if (cleaned.isEmpty || cleaned == '.' || cleaned == '..') {
      return 'download_${DateTime.now().millisecondsSinceEpoch}';
    }
    return cleaned.length > 96
        ? cleaned.substring(cleaned.length - 96)
        : cleaned;
  }

  static String suggestedFileName(
    String url,
    String? contentDisposition,
    String? mimeType,
  ) {
    if (contentDisposition != null) {
      final encoded = RegExp(
        "filename\\*=UTF-8''([^;]+)",
        caseSensitive: false,
      ).firstMatch(contentDisposition);
      if (encoded != null) {
        return sanitizeFileName(Uri.decodeComponent(encoded.group(1)!));
      }
      final plain = RegExp(
        'filename="?([^";]+)"?',
        caseSensitive: false,
      ).firstMatch(contentDisposition);
      if (plain != null) return sanitizeFileName(plain.group(1)!);
    }
    final uri = Uri.tryParse(url);
    final segment = uri != null && uri.pathSegments.isNotEmpty
        ? uri.pathSegments.last
        : '';
    if (segment.isNotEmpty) {
      return sanitizeFileName(Uri.decodeComponent(segment));
    }
    final extension = switch (mimeType) {
      'application/pdf' => '.pdf',
      'image/png' => '.png',
      'image/jpeg' => '.jpg',
      'text/plain' => '.txt',
      _ => '',
    };
    return 'download_${DateTime.now().millisecondsSinceEpoch}$extension';
  }

  static Future<String> _uniquePath(Directory directory, String name) async {
    final dot = name.lastIndexOf('.');
    final stem = dot > 0 ? name.substring(0, dot) : name;
    final extension = dot > 0 ? name.substring(dot) : '';
    var candidate = '${directory.path}${Platform.pathSeparator}$name';
    var index = 1;
    while (await File(candidate).exists()) {
      candidate =
          '${directory.path}${Platform.pathSeparator}$stem ($index)$extension';
      index++;
    }
    return candidate;
  }
}
