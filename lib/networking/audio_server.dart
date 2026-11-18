import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:record/record.dart';

/// Streams the phone's microphone to the desktop on TCP port 5002.
///
/// Format: PCM, 16-bit little-endian, 44100 Hz, mono, sent as chunks, each
/// preceded by its length as a 4-byte big-endian integer. The microphone is
/// only open while the desktop is connected to this port.
class AudioServer {
  AudioServer._internal();

  static final AudioServer _instance = AudioServer._internal();

  factory AudioServer() => _instance;

  static const int port = 5002;
  static const int sampleRate = 44100;

  // Chunks kept while a write is in flight (about two seconds of audio).
  static const int _maxQueued = 100;

  ServerSocket? _server;
  Socket? _client;

  AudioRecorder? _recorder;
  StreamSubscription<Uint8List>? _micSubscription;

  Future<void>? _flushing;
  final List<Uint8List> _queue = [];

  Future<void> start() async {
    if (_server != null) return;

    try {
      _server = await ServerSocket.bind(InternetAddress.anyIPv4, port);
    } catch (e) {
      print("Audio server could not start: $e");
      return;
    }

    print("Audio server listening on port $port");

    _server!.listen(_onClient);
  }

  void _onClient(Socket client) {
    // One listener at a time: a new connection replaces the old one.
    final previous = _client;

    _stopCapture();
    previous?.destroy();

    _client = client;

    print("Audio client connected: ${client.remoteAddress.address}");

    client.setOption(SocketOption.tcpNoDelay, true);

    // Swallow asynchronous socket errors so they cannot surface as
    // unhandled exceptions.
    client.done.then<void>((_) {}, onError: (Object e) {
      print("Audio socket closed with error: $e");
      _dropClient(client);
    });

    client.listen(
      (_) {},
      onDone: () => _dropClient(client),
      onError: (Object e) => _dropClient(client),
      cancelOnError: true,
    );

    unawaited(_startCapture(client));
  }

  void _dropClient(Socket client) {
    if (identical(_client, client)) {
      _client = null;
      _stopCapture();
      print("Audio client disconnected");
    }

    try {
      client.destroy();
    } catch (_) {}
  }

  Future<void> _startCapture(Socket client) async {
    final recorder = AudioRecorder();
    _recorder = recorder;

    try {
      // Asks for the microphone permission the first time.
      if (!await recorder.hasPermission()) {
        print("Microphone permission denied");
        _dropClient(client);
        return;
      }

      final stream = await recorder.startStream(
        const RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: sampleRate,
          numChannels: 1,
        ),
      );

      // The desktop may have left while the permission dialog was open;
      // in that case the capture was already shut down.
      if (!identical(_client, client) || !identical(_recorder, recorder)) {
        return;
      }

      _micSubscription = stream.listen(
        (chunk) => _send(client, chunk),
        onError: (Object e) => print("Microphone error: $e"),
      );

      print("Microphone capture started");
    } catch (e) {
      print("Microphone start failed: $e");
    }
  }

  void _stopCapture() {
    final subscription = _micSubscription;
    final recorder = _recorder;

    _micSubscription = null;
    _recorder = null;
    _flushing = null;
    _queue.clear();

    unawaited(() async {
      try {
        await subscription?.cancel();
      } catch (_) {}
      try {
        await recorder?.stop();
      } catch (_) {}
      try {
        await recorder?.dispose();
      } catch (_) {}
    }());
  }

  void _send(Socket client, Uint8List pcm) {
    if (!identical(_client, client) || pcm.isEmpty) return;

    final header = ByteData(4)..setUint32(0, pcm.length, Endian.big);

    final packet = Uint8List(4 + pcm.length)
      ..setRange(0, 4, header.buffer.asUint8List())
      ..setRange(4, 4 + pcm.length, pcm);

    // Writing while a flush is pending can throw, so hold the chunk until
    // the write in flight has finished.
    if (_flushing != null) {
      if (_queue.length < _maxQueued) {
        _queue.add(packet);
      }
      return;
    }

    _write(client, [packet]);
  }

  void _write(Socket client, List<Uint8List> packets) {
    try {
      for (final packet in packets) {
        client.add(packet);
      }

      _flushing = client.flush().then<void>(
        (_) => _onFlushed(client),
        onError: (Object e) {
          print("Audio flush failed: $e");
          _flushing = null;
          _queue.clear();
        },
      );
    } catch (e) {
      print("Audio write failed: $e");
      _flushing = null;
      _queue.clear();
      _dropClient(client);
    }
  }

  void _onFlushed(Socket client) {
    if (!identical(_client, client)) return;

    _flushing = null;

    if (_queue.isEmpty) return;

    final batch = List<Uint8List>.of(_queue);
    _queue.clear();

    _write(client, batch);
  }
}
