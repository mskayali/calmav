
import 'dart:io';

import 'package:clamav/clamav.dart';
import 'package:test/test.dart';

void main() {
  // Config via env vars for flexibility
  final host = Platform.environment['CLAMAV_HOST'] ?? 'localhost';
  final port = int.tryParse(Platform.environment['CLAMAV_PORT'] ?? '') ?? 3310;
  final cleanFilePath = Platform.environment['CLAMAV_CLEAN_FILE'] ?? '';

  group('Network client', () {
    late Network client;

    setUp(() {
      client = Network(host, port);
    });

    test('ping responds with PONG', () async {
      final alive = await client.ping();
      expect(alive, isTrue);
    });

    test('version is not empty', () async {
      final version = await client.version();
      expect(version, isNotEmpty);
    });

    test('fileScan on clean file returns a bool', () async {
      if (cleanFilePath.isEmpty || !File(cleanFilePath).existsSync()) {
        markTestSkipped(
          'CLAMAV_CLEAN_FILE not set or file does not exist; '
          'set it to a known clean file to run this test.',
        );
      }

      final result = await client.fileScan(cleanFilePath);
      // We do not assert true/false here, only that the call succeeds
      expect(result, isA<bool>());
    });
  });

  group('error handling', () {
    test('throws ClamAVException on unreachable server', () async {
      // Port 9 (discard) is usually closed; adjust if needed
      final badClient = Network('127.0.0.1', 9);

      expect(
        () => badClient.ping(),
        throwsA(isA<ClamAVException>()),
      );
    });
  });
}

class ClamAVException {
}
