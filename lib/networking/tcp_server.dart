import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

class TcpServer {
  TcpServer._internal();

  static final TcpServer _instance = TcpServer._internal();

  factory TcpServer() => _instance;

  ServerSocket? _server;
  Socket? _client;
  Future<void>? _flushing;
  int _sent = 0;
  int _skipped = 0;
  int _statStartMs = DateTime.now().millisecondsSinceEpoch;

  Future<void> start() async {
    if (_server != null) return;

    _server = await ServerSocket.bind(InternetAddress.anyIPv4, 5001);

    print("TCP Server listening on port 5001");

    _server!.listen((Socket client) {
      _client = client;

      print("Desktop connected: ${client.remoteAddress.address}");

      // DO NOT send JSON here.
      // The connection must start with binary frame data.

      // Swallow asynchronous socket errors (for example Broken pipe) so
      // they cannot surface as unhandled exceptions.
      client.done.then<void>((_) {}, onError: (Object e) {
        print("TCP socket closed with error: $e");
        if (identical(_client, client)) _client = null;
      });

      client.listen(
        (data) {
          try {
            final message = utf8.decode(data).trim();

            print("Desktop says: $message");

            if (message == "PING") {
              client.write("PONG");
            }
          } catch (_) {
            // Ignore binary data that isn't text.
          }
        },
        onDone: () {
          print("Desktop disconnected");
          if (identical(_client, client)) _client = null;
        },
        onError: (e) {
          print("TCP Error: $e");
          if (identical(_client, client)) _client = null;
        },
      );
    });
  }

  bool get isConnected => _client != null;

  void sendFrame(Uint8List jpeg) {
    final Socket? client = _client;
    if (client == null) return;

    // A live camera should drop a frame, not queue it: if the previous
    // write has not been flushed to the network yet, skip this one.
    if (_flushing != null) {
      _skipped++;
      _reportStats();
      return;
    }

    try {
      final header = ByteData(4)..setUint32(0, jpeg.length, Endian.big);

      client.add(header.buffer.asUint8List());
      client.add(jpeg);
      _sent++;

      _flushing = client.flush().whenComplete(() {
        _flushing = null;
      }).catchError((Object e) {
        print("flush failed: $e");
      });
    } catch (e) {
      print("sendFrame failed: $e");
      _client = null;
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
