// example/download_and_scan.dart
//
// Example: download a file from the internet and scan it with ClamAV via appwrite_clamav.
//
// Requirements:
// - Dependency in pubspec.yaml:
//     dependencies:
//       http: ^1.2.0
//       appwrite_clamav: ^0.1.0
// - A running clamd instance reachable from this program (e.g. localhost:3310)

import 'dart:io';

import 'package:clamav/clamav.dart';
import 'package:http/http.dart' as http;

Future<void> main() async {
  // Configure ClamAV connection
  final clam = Network(Platform.environment['CLAMAV_HOST'] ?? 'localhost', int.tryParse(Platform.environment['CLAMAV_PORT'] ?? '') ?? 3310);

  // Public example URL (small text file, safe to fetch)
  const url = 'https://www.google.com/robots.txt';

  // Temp file path for scanning
  final tmpDir = Directory.systemTemp;
  final downloadFile = File('${tmpDir.path}/downloaded_from_internet.bin');

  print('Downloading: $url');
  try {
    final response = await http.get(Uri.parse(url));

    if (response.statusCode != 200) {
      stderr.writeln('HTTP error: ${response.statusCode} while downloading $url');
      exitCode = 1;
      return;
    }

    await downloadFile.writeAsBytes(response.bodyBytes);
    print('Downloaded to: ${downloadFile.path}');
  } on SocketException catch (e) {
    stderr.writeln('Network error while downloading: $e');
    exitCode = 1;
    return;
  } catch (e) {
    stderr.writeln('Unexpected error while downloading: $e');
    exitCode = 1;
    return;
  }

  // Ping ClamAV to verify connectivity
  try {
    final alive = await clam.ping();
    if (!alive) {
      stderr.writeln('ClamAV did not respond with PONG.');
      exitCode = 1;
      return;
    }
    print('ClamAV is reachable.');
  } on ClamAVException catch (e) {
    stderr.writeln('Failed to ping ClamAV: $e');
    exitCode = 1;
    return;
  }

  // Scan the downloaded file
  try {
    final isClean = await clam.fileScan(downloadFile.path);

    print('Scan result for ${downloadFile.path}:');
    if (isClean) {
      print('  -> CLEAN');
    } else {
      print('  -> INFECTED');
    }
  } on ClamAVException catch (e) {
    stderr.writeln('ClamAV scan error: $e');
    exitCode = 1;
  } catch (e) {
    stderr.writeln('Unexpected error during scan: $e');
    exitCode = 1;
  } finally {
    // Clean up the temporary file
    if (await downloadFile.exists()) {
      await downloadFile.delete();
      print('Temporary file removed: ${downloadFile.path}');
    }
  }
}
