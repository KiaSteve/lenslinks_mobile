package com.example.lenslinks_mobile

import android.graphics.ImageFormat
import android.graphics.Rect
import android.graphics.YuvImage
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {

    private val executor = Executors.newSingleThreadExecutor()
    private val mainHandler = Handler(Looper.getMainLooper())

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "lenslinks/encoder")
            .setMethodCallHandler { call, result ->
                if (call.method != "encodeYuv") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }

                val width = call.argument<Int>("width") ?: 0
                val height = call.argument<Int>("height") ?: 0
                val y = call.argument<ByteArray>("y")
                val u = call.argument<ByteArray>("u")
                val v = call.argument<ByteArray>("v")
                val yRowStride = call.argument<Int>("yRowStride") ?: width
                val uvRowStride = call.argument<Int>("uvRowStride") ?: width
                val uvPixelStride = call.argument<Int>("uvPixelStride") ?: 1
                val rotate = call.argument<Int>("rotate") ?: 0
                val quality = call.argument<Int>("quality") ?: 70

                if (y == null || u == null || v == null || width <= 0 || height <= 0) {
                    result.error("bad_args", "Missing planes or size", null)
                    return@setMethodCallHandler
                }

                executor.execute {
                    try {
                        var nv21 = yuvToNv21(
                            width, height, y, u, v,
                            yRowStride, uvRowStride, uvPixelStride
                        )
                        var outW = width
                        var outH = height

                        if (rotate == 90) {
                            nv21 = rotateNv21Cw90(nv21, width, height)
                            outW = height
                            outH = width
                        }

                        val yuv = YuvImage(nv21, ImageFormat.NV21, outW, outH, null)
                        val out = ByteArrayOutputStream(64 * 1024)
                        yuv.compressToJpeg(Rect(0, 0, outW, outH), quality, out)
                        val jpg = out.toByteArray()

                        mainHandler.post { result.success(jpg) }
                    } catch (e: Exception) {
                        mainHandler.post { result.error("encode_failed", e.toString(), null) }
                    }
                }
            }
    }

    // Converts the camera's YUV_420_888 planes to a tightly packed NV21 buffer.
    // Assumes even width and height, which camera sizes always are.
    private fun yuvToNv21(
        width: Int, height: Int,
        y: ByteArray, u: ByteArray, v: ByteArray,
        yRowStride: Int, uvRowStride: Int, uvPixelStride: Int
    ): ByteArray {
        val nv21 = ByteArray(width * height * 3 / 2)
        var pos = 0

        if (yRowStride == width) {
            System.arraycopy(y, 0, nv21, 0, width * height)
            pos = width * height
        } else {
            for (row in 0 until height) {
                System.arraycopy(y, row * yRowStride, nv21, pos, width)
                pos += width
            }
        }

        val chromaW = width / 2
        val chromaH = height / 2
        for (row in 0 until chromaH) {
            var idx = row * uvRowStride
            for (col in 0 until chromaW) {
                nv21[pos++] = v[idx]
                nv21[pos++] = u[idx]
                idx += uvPixelStride
            }
        }
        return nv21
    }

    // Rotates an NV21 buffer 90 degrees clockwise: source (x, y) -> (h - 1 - y, x).
    private fun rotateNv21Cw90(src: ByteArray, w: Int, h: Int): ByteArray {
        val dst = ByteArray(src.size)
        var i = 0

        for (x in 0 until w) {
            for (y in h - 1 downTo 0) {
                dst[i++] = src[y * w + x]
            }
        }

        val frameSize = w * h
        val cw = w / 2
        val ch = h / 2
        var j = frameSize
        for (cx in 0 until cw) {
            for (cy in ch - 1 downTo 0) {
                val s = frameSize + (cy * cw + cx) * 2
                dst[j++] = src[s]
                dst[j++] = src[s + 1]
            }
        }
        return dst
    }
}
