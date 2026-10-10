import '../networking/udp_listener.dart';

class DiscoveryService {
  final UdpListener _listener = UdpListener();

  Future<void> start() async {
    await _listener.start();
  }

  void stop() {
    _listener.stop();
  }
}
