import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:clamav/src/exceptions.dart';

abstract class ClamAVClient {
  /// INSTREAM chunk size (bytes). 16 KB gayet yeterli.
  static const int defaultChunkSize = 16 * 1024;

  final int chunkSize;

  ClamAVClient({this.chunkSize = defaultChunkSize});

  /// Alt sınıf, uygun Socket’i açmakla sorumlu.
  Future<Socket> connect();

  /// PING komutu. true = ClamAV ayakta.
  Future<bool> ping() async {
    final response = await _sendSimpleCommand('PING');
    return response.trim() == 'PONG';
  }

  /// VERSION komutu. ClamAV versiyon stringi döner.
  Future<String> version() async {
    final response = await _sendSimpleCommand('VERSION');
    return response.trim();
  }

  /// RELOAD komutu. DB reload eder. Hata yoksa true.
  Future<bool> reload() async {
    final response = await _sendSimpleCommand('RELOAD');
    // clamd genelde "RELOADING" veya benzeri döner; sadece hata olmadığını kontrol ediyoruz.
    return !response.toUpperCase().contains('ERROR');
  }

  /// SHUTDOWN komutu. Hata yoksa true.
  Future<bool> shutdown() async {
    final response = await _sendSimpleCommand('SHUTDOWN');
    return !response.toUpperCase().contains('ERROR');
  }

  /// PHP tarafındaki `fileScan('path/to/file')`’in birebir karşılığı.
  ///
  /// true  -> dosya temiz
  /// false -> dosya enfekte (FOUND)
  ///
  /// Hata durumlarında [ClamAVException] fırlatır.
  Future<bool> fileScan(String path) async {
    final file = File(path);
    if (!await file.exists()) {
      throw ClamAVException('File not found: $path');
    }

    final socket = await _safeConnect();
    final responseFuture = _readAll(socket);

    try {
      // INSTREAM komutu – zINSTREAM\0 kullanıyoruz
      socket.add(utf8.encode('zINSTREAM\0'));

      final fileStream = file.openRead();
      await for (final chunk in fileStream) {
        if (chunk.isEmpty) continue;

        if (chunk.length > chunkSize) {
          // Parçalara bölelim
          var offset = 0;
          while (offset < chunk.length) {
            final end = (offset + chunkSize < chunk.length) ? offset + chunkSize : chunk.length;
            final slice = chunk.sublist(offset, end);
            _writeLengthPrefixedChunk(socket, slice);
            offset = end;
          }
        } else {
          _writeLengthPrefixedChunk(socket, chunk);
        }
      }

      // 0 uzunluklu chunk ile stream’i bitir
      final zero = ByteData(4)..setUint32(0, 0, Endian.big);
      socket.add(zero.buffer.asUint8List());
      await socket.flush();
      await socket.close();

      final response = await responseFuture;
      return _parseScanResponse(response);
    } catch (e) {
      socket.destroy();
      rethrow;
    }
  }

  // --- alt yardımcılar ---

  Future<String> _sendSimpleCommand(String command) async {
    final socket = await _safeConnect();
    final responseFuture = _readAll(socket);

    try {
      socket.add(utf8.encode('$command\n'));
      await socket.flush();
      await socket.close();
      return await responseFuture;
    } catch (e) {
      socket.destroy();
      throw ClamAVException('Failed to send command: $command', cause: e);
    }
  }

  Future<Socket> _safeConnect() async {
    try {
      return await connect();
    } on TimeoutException catch (e) {
      throw ClamAVException('Unable to connect to ClamAV server (timeout).', cause: e);
    } on SocketException catch (e) {
      // PHP paketindeki hata mesajına yaklaşıyoruz:
      throw ClamAVException('Unable to connect to ClamAV server', cause: e);
    } catch (e) {
      throw ClamAVException('Unknown error while connecting to ClamAV', cause: e);
    }
  }

  void _writeLengthPrefixedChunk(Socket socket, List<int> chunk) {
    final lengthBytes = ByteData(4)..setUint32(0, chunk.length, Endian.big);
    socket.add(lengthBytes.buffer.asUint8List());
    socket.add(chunk);
  }

  Future<String> _readAll(Socket socket) async {
    final buffer = BytesBuilder();
    await for (final data in socket) {
      buffer.add(data);
    }
    return utf8.decode(buffer.toBytes());
  }

  /// `stream: OK` / `stream: <virus> FOUND` / `... ERROR`
  bool _parseScanResponse(String response) {
    final normalized = response.trim();

    if (normalized.isEmpty) {
      throw ClamAVException('Empty response from ClamAV');
    }

    // Basit bir parse: “FOUND” var mı diye bak.
    if (normalized.toUpperCase().contains('FOUND')) {
      return false; // enfekte
    }

    if (normalized.toUpperCase().contains('ERROR')) {
      throw ClamAVException('ClamAV error: $normalized');
    }

    // Klasik OK formatları: "stream: OK", "OK"
    return true;
  }
}
