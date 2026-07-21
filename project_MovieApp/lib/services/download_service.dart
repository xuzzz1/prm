import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:ffmpeg_kit_flutter_new_https/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new_https/ffmpeg_kit_config.dart';
import 'package:ffmpeg_kit_flutter_new_https/return_code.dart';
import 'package:ffmpeg_kit_flutter_new_https/statistics.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;
import '../models/download.dart';

typedef ProgressCallback = void Function(double? progress, String? stage, int? downloadedBytes, int? totalBytes);

class DownloadService {
  static const String _downloadFolder = 'MovieAppDownloads';

  Future<String> get _downloadPath async {
    final dir = await getApplicationDocumentsDirectory();
    final downloadDir = Directory('${dir.path}/$_downloadFolder');
    if (!await downloadDir.exists()) {
      await downloadDir.create(recursive: true);
    }
    return downloadDir.path;
  }

  Future<bool> requestPermissions() async {
    if (Platform.isAndroid) {
      final status = await Permission.storage.status;
      if (status.isDenied) {
        final result = await Permission.storage.request();
        return result.isGranted;
      }
      return true;
    }
    return true;
  }

  Future<int?> getFileSize(String url) async {
    try {
      final response = await http.head(Uri.parse(url));
      final contentLength = response.headers['content-length'];
      if (contentLength != null) {
        return int.tryParse(contentLength);
      }
    } catch (e) {
      // silent
    }
    return null;
  }

  Future<int?> getM3U8Duration(String url) async {
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final content = response.body;
        final lines = content.split('\n');
        int totalDuration = 0;
        for (var line in lines) {
          if (line.startsWith('#EXTINF:')) {
            final duration = double.tryParse(line.split(':')[1].split(',')[0]);
            if (duration != null) {
              totalDuration += duration.toInt();
            }
          }
        }
        return totalDuration > 0 ? totalDuration : null;
      }
    } catch (e) {
      // silent
    }
    return null;
  }

  Future<String?> downloadAndCompress({
    required String url,
    required String outputName,
    required DownloadQuality quality,
    Map<String, String>? headers,
    ProgressCallback? onProgress,
  }) async {
    try {
      final downloadDir = await _downloadPath;
      final outputPath = '$downloadDir/$outputName.mp4';

      final existingFile = File(outputPath);
      if (await existingFile.exists()) {
        return outputPath;
      }

      String command = '-i "$url" '
          '-c copy '
          '-movflags +faststart '
          '-y '
          '"$outputPath"';

      if (headers != null) {
        // FFmpeg -headers expects \r\n line terminators
        final headerString =
            headers.entries.map((e) => '${e.key}: ${e.value}').join('\r\n');
        command = '-headers "$headerString\r\n" $command';
      }

      final session = await FFmpegKit.execute(command);
      final returnCode = await session.getReturnCode();

      if (ReturnCode.isSuccess(returnCode)) {
        final finalFile = File(outputPath);
        if (await finalFile.exists()) {
          return outputPath;
        }
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  Future<String?> downloadWithProgress({
    required String url,
    required String outputName,
    required DownloadQuality quality,
    Map<String, String>? headers,
    ProgressCallback? onProgress,
  }) async {
    try {
      final downloadDir = await _downloadPath;
      final outputPath = '$downloadDir/$outputName.mp4';

      final existingFile = File(outputPath);
      if (await existingFile.exists()) {
        final stat = await existingFile.stat();
        onProgress?.call(1.0, 'completed', stat.size, stat.size);
        return outputPath;
      }

      // Test the URL with direct HTTP request to see actual server response
      try {
        final testResponse = await HttpClient()
            .openUrl('GET', Uri.parse(url))
            .then((request) {
          headers?.forEach((key, value) => request.headers.set(key, value));
          return request.close();
        });
        final statusCode = testResponse.statusCode;
        final body = await testResponse.transform(utf8.decoder).join();
        if (statusCode != 200) {
          throw Exception('HTTP test failed: $statusCode — $body');
        }
      } catch (e) {
        // silent
      }

      // Build command — use copy/remux (no re-encoding) since libx264 is not available
      // in the min build. The m3u8 already specifies quality, so no scaling needed.
      String command = '-loglevel info -i "$url" '
          '-c copy '
          '-movflags +faststart '
          '-progress pipe:1 '
          '-y '
          '"$outputPath"';

      if (headers != null) {
        // FFmpeg -headers expects \r\n line terminators
        final headerString =
            headers.entries.map((e) => '${e.key}: ${e.value}').join('\r\n');
        command = '-headers "$headerString\r\n" $command';
      }

      // Register statistics callback BEFORE executing so we capture all progress
      void handleStatistics(Statistics statistics) {
        final timeMs = statistics.getTime();
        if (timeMs > 0) {
          final size = statistics.getSize();
          final bytesPerSec = statistics.getBitrate();
          onProgress?.call(
            null, // no total duration available
            bytesPerSec > 0 ? 'Đang tải' : 'Đang xử lý',
            size,
            null,
          );
        }
      }

      FFmpegKitConfig.enableStatisticsCallback(handleStatistics);

      final session = await FFmpegKit.execute(command);

      final returnCode = await session.getReturnCode();

      if (ReturnCode.isSuccess(returnCode)) {
        final finalFile = File(outputPath);
        if (await finalFile.exists()) {
          final stat = await finalFile.stat();
          onProgress?.call(1.0, 'completed', stat.size, stat.size);
          return outputPath;
        }
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  Future<String?> simpleDownload({
    required String url,
    required String outputName,
    ProgressCallback? onProgress,
  }) async {
    try {
      final downloadDir = await _downloadPath;
      final outputPath = '$downloadDir/$outputName.mp4';

      final existingFile = File(outputPath);
      if (await existingFile.exists()) {
        final stat = await existingFile.stat();
        onProgress?.call(1.0, 'completed', stat.size, stat.size);
        return outputPath;
      }

      final command = '''
        -i "$url"
        -c copy
        -movflags +faststart
        -y
        "$outputPath"
      ''';

      final session = await FFmpegKit.execute(command);
      final returnCode = await session.getReturnCode();

      if (ReturnCode.isSuccess(returnCode)) {
        final finalFile = File(outputPath);
        if (await finalFile.exists()) {
          final stat = await finalFile.stat();
          onProgress?.call(1.0, 'completed', stat.size, stat.size);
          return outputPath;
        }
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  Future<bool> deleteDownload(String localPath) async {
    try {
      final file = File(localPath);
      if (await file.exists()) {
        await file.delete();
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  Future<int> getDownloadSize(String localPath) async {
    try {
      final file = File(localPath);
      if (await file.exists()) {
        final stat = await file.stat();
        return stat.size;
      }
    } catch (e) {
      // silent
    }
    return 0;
  }

  Future<List<String>> getAllDownloads() async {
    try {
      final downloadDir = await _downloadPath;
      final dir = Directory(downloadDir);
      if (await dir.exists()) {
        final files = await dir.list().toList();
        return files
            .whereType<File>()
            .where((f) => f.path.endsWith('.mp4'))
            .map((f) => f.path)
            .toList();
      }
    } catch (e) {
      // silent
    }
    return [];
  }

  Future<int> getTotalDownloadedSize() async {
    final downloads = await getAllDownloads();
    int total = 0;
    for (var path in downloads) {
      total += await getDownloadSize(path);
    }
    return total;
  }

  Future<bool> clearAllDownloads() async {
    try {
      final downloadDir = await _downloadPath;
      final dir = Directory(downloadDir);
      if (await dir.exists()) {
        await dir.delete(recursive: true);
        await dir.create();
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }
}
