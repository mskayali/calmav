import 'dart:async';
import 'dart:io';

import 'clamav_client.dart';

class Pipe extends ClamAVClient {
  final String socketPath;
  final Duration timeout;

  Pipe(this.socketPath, {Duration? timeout, int chunkSize = ClamAVClient.defaultChunkSize})
    : timeout = timeout ?? const Duration(seconds: 5),
      super(chunkSize: chunkSize);

  @override
  Future<Socket> connect() {
    final address = InternetAddress(socketPath, type: InternetAddressType.unix);

    // Unix domain socket, port 0
    return Socket.connect(address, 0, timeout: timeout);
  }
}
