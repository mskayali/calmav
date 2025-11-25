

## Quick Start
Dart client for the ClamAV daemon (`clamd`) over TCP or Unix domain sockets.

- Talks directly to `clamd` using its native protocol
- Supports `PING`, `VERSION`, `RELOAD`, `SHUTDOWN`, `INSTREAM`
- Designed for server-side Dart / CLI / Flutter mobile/desktop
### TCP (Network)

```dart
import 'package:clamav/clamav.dart';

Future<void> main() async {
  // ClamAV clamd TCP socket (e.g. port 3310)
  final clam = Network('localhost', 3310);

  final isAlive = await clam.ping();
  print('ClamAV alive: $isAlive');

  final version = await clam.version();
  print('ClamAV version: $version');

  final isClean = await clam.fileScan('/path/to/file.dmg');
  print('File clean: $isClean');

  await clam.reload();   // optional
  await clam.shutdown(); // optional, typically not used in production
}
```

### Unix Domain Socket (Pipe)

```dart
import 'package:clamav/clamav.dart';

Future<void> main() async {
  // Example socket path (Linux):
  // /var/run/clamav/clamd.ctl or /run/clamav/clamd.ctl
  final clam = Pipe('/var/run/clamav/clamd.sock');

  final isAlive = await clam.ping();
  print('ClamAV alive: $isAlive');

  final version = await clam.version();
  print('ClamAV version: $version');

  final isClean = await clam.fileScan('/path/to/file.dmg');
  print('File clean: $isClean');
}
```

---

## Library API

Entry point:

```dart
import 'package:clamav/clamav.dart';
```

Exported types:

* `Network` – TCP client
* `Pipe` – Unix domain socket client
* `ClamAVClient` – abstract base class
* `ClamAVException` – error type

### Network

```dart
class Network extends ClamAVClient {
  Network(
    String host,
    int port, {
    Duration? timeout,
    int chunkSize = ClamAVClient.defaultChunkSize,
  });
}
```

Parameters:

* `host`: `clamd` host
* `port`: `clamd` TCP port (commonly `3310`)
* `timeout`: connect timeout (default: 5 seconds)
* `chunkSize`: `INSTREAM` chunk size in bytes (default: 16 KB)

Example:

```dart
final clam = Network('localhost', 3310);
```

### Pipe

```dart
class Pipe extends ClamAVClient {
  Pipe(
    String socketPath, {
    Duration? timeout,
    int chunkSize = ClamAVClient.defaultChunkSize,
  });
}
```

Parameters:

* `socketPath`: Unix domain socket path
* `timeout` / `chunkSize`: same semantics as `Network`

Example:

```dart
final clam = Pipe('/var/run/clamav/clamd.sock');
```

### Shared Methods (ClamAVClient)

Both `Network` and `Pipe` provide the same methods.

#### `Future<bool> ping()`

Sends a `PING` command.

* Returns `true` if `clamd` responds with `PONG`
* Throws `ClamAVException` on errors (connection, protocol, etc.)

```dart
final ok = await clam.ping();
```

#### `Future<String> version()`

Sends a `VERSION` command.

```dart
final version = await clam.version();
print(version); // e.g. "ClamAV 1.2.3/12345/Mon Jan 01 00:00:00 2024"
```

#### `Future<bool> fileScan(String path)`

Scans a **file on disk** using `INSTREAM`.

Return value:

* `true` → file is clean
* `false` → file is infected
* Throws `ClamAVException` on errors (file not found, protocol error, etc.)

```dart
final isClean = await clam.fileScan('/tmp/upload.bin');

if (!isClean) {
  // reject file, log, etc.
}
```

#### `Future<bool> reload()`

Sends a `RELOAD` command to `clamd` to reload its virus database.

* Returns `true` if no error is detected in the response
* Throws `ClamAVException` on error

```dart
await clam.reload();
```

#### `Future<bool> shutdown()`

Sends a `SHUTDOWN` command to `clamd`.

* Mainly useful in development/test environments
* Returns `true` on success, throws `ClamAVException` on error

```dart
await clam.shutdown();
```

---

## Error Handling

All network/IO/protocol errors are wrapped in `ClamAVException`.

```dart
import 'package:clamav/clamav.dart';

Future<void> main() async {
  final clam = Network('localhost', 3310);

  try {
    final clean = await clam.fileScan('/path/to/file.dmg');
    print('Clean: $clean');
  } on ClamAVException catch (e) {
    // clamd not running, network error, protocol error, etc.
    print('ClamAV error: $e');
  }
}
```

Example error messages:

* `ClamAVException: Unable to connect to ClamAV server (SocketException: ...)`
* `ClamAVException: Empty response from ClamAV`
* `ClamAVException: ClamAV error: stream: <details> ERROR`

---

## INSTREAM Protocol Details

`fileScan` uses the `INSTREAM` protocol of `clamd`:

1. Send the command: `zINSTREAM\0`
2. Send the file content as a sequence of chunks

   * Each chunk is prefixed by a 4-byte big-endian length
   * Followed immediately by the raw chunk bytes
3. Terminate the stream with a zero-length chunk (`0x00000000`)
4. Read the response, which typically looks like:

   * `stream: OK`
   * `stream: <virus name> FOUND`
   * `stream: <details> ERROR`

The library interprets the response as:

* Contains `FOUND` → returns `false` (infected)
* Contains `ERROR` → throws `ClamAVException`
* Otherwise → returns `true` (clean)

---

## Requirements

* Dart SDK: `>=2.17.0 <4.0.0`
* A running ClamAV `clamd` instance:

  * Listening on TCP (`TCPSocket` / `TCPAddr` in `clamd.conf`), or
  * Listening on a Unix domain socket (`LocalSocket` / `LocalSocketGroup`)

Example Docker usage:

```bash
docker run --rm -p 3310:3310 clamav/clamav:latest
```

Then in Dart:

```dart
final clam = Network('localhost', 3310);
```

or use the container hostname / IP as appropriate.

---

## Contributing / License

This package is a Dart client for ClamAV based on the behavior of the Appwrite ecosystem.

* Use standard Dart/Flutter formatting (`dart format`)
* Add tests for new features
* Open issues/PRs on the repository if you encounter bugs or want to propose improvements

Check the `LICENSE` file in the repository for licensing details.
