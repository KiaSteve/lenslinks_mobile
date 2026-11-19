import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'pairing.dart';
import 'pairing_store.dart';

class TcpServer {
  TcpServer._internal();

  static final TcpServer _instance = TcpServer._internal();

  factory TcpServer() => _instance;

  ServerSocket? _server;
  Socket? _client;
  SecureWriter? _writer;
  Future<void>? _flushing;
  int _sent = 0;
  int _skipped = 0;
  int _statStartMs = DateTime.now().millisecondsSinceEpoch;

  Future<void> start() async {
    if (_server != null) return;

    _server = await ServerSocket.bind(InternetAddress.anyIPv4, 5001);

    print("TCP Server listening on port 5001");

    _server!.listen(_onClient);
  }

  void _onClient(Socket client) {
    final String ip = client.remoteAddress.address;
    final PairingGuard guard = PairingGuard.instance;

    // A PC that has guessed wrong too often is turned away at once.
    if (guard.isLocked(ip)) {
      print("Connection from $ip refused (too many wrong pairing keys)");
      client.destroy();
      return;
    }

    final PairingServer handshake = PairingServer(
      key: PairingStore.instance.key,
      send: client.add,
    );

    bool authenticated = false;

    // Someone who connects and then says nothing must not hold the socket.
    final Timer timeout = Timer(const Duration(seconds: 5), () {
      if (!authenticated) {
        print("Pairing timed out for $ip");
        client.destroy();
      }
    });

    // Swallow asynchronous socket errors (for example Broken pipe) so
    // they cannot surface as unhandled exceptions.
    client.done.then<void>((_) {}, onError: (Object e) {
      print("TCP socket closed with error: $e");
      if (identical(_client, client)) {
        _client = null;
        _writer = null;
      }
    });

    // No video is sent until the PC has proved it knows the pairing key.
    // Everything after that is encrypted.
    handshake.begin();

    client.listen(
      (data) {
        // After the handshake the PC sends nothing.
        if (authenticated) return;

        handshake.feed(data);

        if (handshake.result == PairingResult.pending) return;

        timeout.cancel();

        if (handshake.result != PairingResult.accepted) {
          guard.recordFailure(ip);
          print("Pairing key refused for $ip");
          _closeAfterFlush(client);
          return;
        }

        authenticated = true;
        guard.recordSuccess(ip);

        _writer = SecureWriter(handshake.keys!);
        _client = client;

        print("Desktop connected (encrypted): $ip");
      },
      onDone: () {
        timeout.cancel();
        if (authenticated) print("Desktop disconnected");
        if (identical(_client, client)) {
          _client = null;
          _writer = null;
        }
      },
      onError: (e) {
        timeout.cancel();
        print("TCP Error: $e");
        if (identical(_client, client)) {
          _client = null;
          _writer = null;
        }
      },
    );
  }

  // Lets the "refused" byte reach the PC before the socket is closed.
  void _closeAfterFlush(Socket client) {
    try {
      client.flush().then<void>((_) {}, onError: (Object _) {}).whenComplete(
        client.destroy,
      );
    } catch (_) {
      client.destroy();
    }
  }

  bool get isConnected => _client != null;

  /// Disconnects the current desktop (for example after a new pairing key).
  void disconnectClient() {
    final Socket? client = _client;

    _client = null;
    _writer = null;

    try {
      client?.destroy();
    } catch (_) {}
  }

  void sendFrame(Uint8List jpeg) {
    final Socket? client = _client;
    final SecureWriter? writer = _writer;
    if (client == null || writer == null) return;

    // A live camera should drop a frame, not queue it: if the previous
    // write has not been flushed to the network yet, skip this one.
    if (_flushing != null) {
      _skipped++;
      _reportStats();
      return;
    }

    try {
      // One packet: 4-byte length, then the JPEG. It is sent as one encrypted
      // record.
      final packet = Uint8List(4 + jpeg.length);

      ByteData.sublistView(packet).setUint32(0, jpeg.length, Endian.big);
      packet.setRange(4, packet.length, jpeg);

      client.add(writer.seal(packet));
      _sent++;

      _flushing = client.flush().whenComplete(() {
        _flushing = null;
      }).catchError((Object e) {
        print("flush failed: $e");
      });
    } catch (e) {
      print("sendFrame failed: $e");
      _client = null;
      _writer = null;
      _flushing = null;
    }

    _reportStats();
  }

  void _reportStats() {
    final int nowMs = DateTime.now().millisecondsSinceEpoch;
    if (nowMs - _statStartMs >= 5000) {
      final double secs = (nowMs - _statStartMs) / 1000;
      print("SEND: ${(_sent / secs).toStringAsFixed(1)} sent/s, "
          "${(_skipped / secs).toStringAsFixed(1)} skipped/s");
      _sent = 0;
      _skipped = 0;
      _statStartMs = nowMs;
    }
  }
}
