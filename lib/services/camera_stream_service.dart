import 'package:camera/camera.dart';

import '../camera/camera_service.dart';
import '../camera/frame_encoder.dart';
import '../networking/tcp_server.dart';

class CameraStreamService {
  final CameraService _cameraService;
  final TcpServer _tcpServer;

  bool _streaming = false;
  bool _busy = false;

  CameraStreamService(this._cameraService, this._tcpServer);

  Future<void> start() async {
    if (_streaming) return;

    _streaming = true;

    await _cameraService.startImageStream((CameraImage image) async {
      if (!_streaming || _busy) return;

      _busy = true;

      try {
        final jpg = await FrameEncoder.encode(image);

        _tcpServer.sendFrame(jpg);

        // print("Frame sent (${jpg.length} bytes)");
      } catch (e) {
        print("Frame error: $e");
      }

      _busy = false;
    });
  }

  Future<void> stop() async {
    _streaming = false;
    await _cameraService.stopImageStream();
  }
}
