
import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;

class FrameEncoder {
  static const MethodChannel _channel = MethodChannel('lenslinks/encoder');
  static const int _quality = 70;
  static const int _rotateDegrees = 90;

  static bool _nativeFailed = false;

  // Timing statistics, printed every ~5 seconds.
  static int _frames = 0;
  static int _totalUs = 0;
  static int _lastReportMs = DateTime.now().millisecondsSinceEpoch;

  static Future<Uint8List> encode(CameraImage image) async {
    final Stopwatch sw = Stopwatch()..start();

    Uint8List? jpg;
    String path = 'dart';

    if (!_nativeFailed) {
      try {
        final Uint8List? nativeJpg = await _channel.invokeMethod<Uint8List>(
          'encodeYuv',
          <String, Object>{
            'width': image.width,
            'height': image.height,
            'y': image.planes[0].bytes,
            'u': image.planes[1].bytes,
            'v': image.planes[2].bytes,
            'yRowStride': image.planes[0].bytesPerRow,
            'uvRowStride': image.planes[1].bytesPerRow,
            'uvPixelStride': image.planes[1].bytesPerPixel ?? 1,
            'rotate': _rotateDegrees,
            'quality': _quality,
          },
        );
        if (nativeJpg != null) {
          jpg = nativeJpg;
          path = 'native';
        }
      } catch (e) {
        _nativeFailed = true;
        print('Native encoder failed, using Dart fallback: $e');
      }
    }

    jpg ??= _encodeDart(image);

    _frames++;
    _totalUs += sw.elapsedMicroseconds;

    final int nowMs = DateTime.now().millisecondsSinceEpoch;
    if (nowMs - _lastReportMs >= 5000) {
      final double secs = (nowMs - _lastReportMs) / 1000;
      print(
        'ENC: $path ${image.width}x${image.height}, '
        '${(_frames / secs).toStringAsFixed(1)} fps, '
        '${(_totalUs / _frames / 1000).toStringAsFixed(1)} ms/frame, '
        '${jpg.length} bytes',
      );
      _frames = 0;
      _totalUs = 0;
      _lastReportMs = nowMs;
    }

    return jpg;
  }

  // Slow pure-Dart fallback, used only if the native encoder is unavailable.
  static Uint8List _encodeDart(CameraImage image) {
    final int width = image.width;
    final int height = image.height;

    final Uint8List yBytes = image.planes[0].bytes;
    final Uint8List uBytes = image.planes[1].bytes;
    final Uint8List vBytes = image.planes[2].bytes;

    final int yRowStride = image.planes[0].bytesPerRow;
    final int uvRowStride = image.planes[1].bytesPerRow;
    final int uvPixelStride = image.planes[1].bytesPerPixel ?? 1;

    final int outW = height;
    final int outH = width;
    final Uint8List rgb = Uint8List(outW * outH * 3);

    for (int y = 0; y < height; y++) {
      final int yRow = y * yRowStride;
      final int uvRow = (y >> 1) * uvRowStride;
      final int outX = height - 1 - y;

      for (int x = 0; x < width; x++) {
        final int c = yBytes[yRow + x] - 16;
        final int uvIndex = uvRow + (x >> 1) * uvPixelStride;
        final int d = uBytes[uvIndex] - 128;
        final int e = vBytes[uvIndex] - 128;

        final int r = ((298 * c + 409 * e + 128) >> 8).clamp(0, 255);
        final int g = ((298 * c - 100 * d - 208 * e + 128) >> 8).clamp(0, 255);
        final int b = ((298 * c + 516 * d + 128) >> 8).clamp(0, 255);

        final int o = (x * outW + outX) * 3;
        rgb[o] = r;
        rgb[o + 1] = g;
        rgb[o + 2] = b;
      }
    }

    final img.Image rotated = img.Image.fromBytes(
      width: outW,
      height: outH,
      bytes: rgb.buffer,
      numChannels: 3,
    );

    return img.encodeJpg(rotated, quality: _quality);
  }
}
