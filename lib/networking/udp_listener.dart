import 'dart:io';

import 'protocol.dart';

class UdpListener {
  RawDatagramSocket? _socket;

  Future<void> start() async {
    _socket = await RawDatagramSocket.bind(
      InternetAddress.anyIPv4,
      discoveryPort,
    );

    print("Listening on port $discoveryPort");

    _socket!.listen((event) {
      if (event == RawSocketEvent.read) {
        final datagram = _socket!.receive();

        if (datagram == null) return;

        final message = String.fromCharCodes(datagram.data);

        print("Received: $message");

        if (message == discoveryRequest) {
          print("Desktop discovered.");

          _socket!.send(
            discoveryResponse.codeUnits,
            datagram.address,
            datagram.port,
          );
        }
      }
    });
  }

  Future<void> stop() async {
    _socket?.close();
  }
}
