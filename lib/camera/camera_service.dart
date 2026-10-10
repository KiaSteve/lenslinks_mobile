import 'package:camera/camera.dart';

class CameraService {
  CameraController? controller;

  Future<void> initialize() async {
    final cameras = await availableCameras();

    final camera = cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.back,
      orElse: () => cameras.first,
    );

    controller = CameraController(
      camera,
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.yuv420,
    );

    await controller!.initialize();
  }

  Future<void> startImageStream(Function(CameraImage image) onFrame) async {
    if (controller == null) return;

    if (controller!.value.isStreamingImages) return;

    await controller!.startImageStream(onFrame);
  }

  Future<void> stopImageStream() async {
    if (controller == null) return;

    if (controller!.value.isStreamingImages) {
      await controller!.stopImageStream();
    }
  }

  Future<void> dispose() async {
    await stopImageStream();
    await controller?.dispose();
    controller = null;
  }
}
