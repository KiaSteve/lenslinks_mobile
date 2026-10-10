import 'dart:convert';
import 'dart:io';

import 'protocol.dart';

class UdpListener {
  RawDatagramSocket? _socket;

  Future<void> start() async {
    // Prevent starting twice
    if (_socket != null) return;

    _socket = await RawDatagramSocket.bind(
      InternetAddress.anyIPv4,
      discoveryPort,
      reuseAddress: true,
    );

    _socket!.broadcastEnabled = true;

    print("UDP Listener started on ${_socket!.address.address}:$discoveryPort");

    _socket!.listen((event) {
      if (event != RawSocketEvent.read) return;

      final datagram = _socket!.receive();
      if (datagram == null) return;

      final message = utf8.decode(datagram.data);

      print(
        "Received '$message' from ${datagram.address.address}:${datagram.port}",
      );

      if (message == discoveryRequest) {
        print("Sending discovery response...");

        _socket!.send(
          utf8.encode(discoveryResponse),
          datagram.address,
          datagram.port,
        );

        print(
          "Discovery response sent to ${datagram.address.address}:${datagram.port}",
        );
      }
    });
  }

  Future<void> stop() async {
    _socket?.close();
    _socket = null;
  }
}
