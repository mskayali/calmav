import 'dart:async';
import 'dart:io';

import 'clamav_client.dart';

class Network extends ClamAVClient {
  final String host;
  final int port;
  final Duration timeout;

  Network(this.host, this.port, {Duration? timeout, int chunkSize = ClamAVClient.defaultChunkSize})
    : timeout = timeout ?? const Duration(seconds: 5),
      super(chunkSize: chunkSize);

  @override
  Future<Socket> connect() {
    return Socket.connect(host, port, timeout: timeout);
  }
}
