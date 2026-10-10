import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../camera/camera_service.dart';
import '../services/camera_stream_service.dart';
import '../networking/tcp_server.dart';
import '../services/discovery_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final DiscoveryService discovery = DiscoveryService();
  final CameraService cameraService = CameraService();
  final TcpServer tcpServer = TcpServer();

  CameraStreamService? streamService;

  bool loading = true;
  String status = "Initializing...";

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    await discovery.start();

    await cameraService.initialize();

    streamService = CameraStreamService(cameraService, tcpServer);

    // Start streaming camera frames
    await streamService!.start();

    if (!mounted) return;

    setState(() {
      loading = false;
      status = "Streaming camera...";
    });
  }

  @override
  void dispose() {
    streamService?.stop();
    discovery.stop();
    cameraService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final CameraController? controller = cameraService.controller;

    return Scaffold(
      appBar: AppBar(title: const Text("LensLinks Mobile"), centerTitle: true),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: controller != null && controller.value.isInitialized
                      ? CameraPreview(controller)
                      : const Center(
                          child: Text(
                            "Camera unavailable",
                            style: TextStyle(fontSize: 18),
                          ),
                        ),
                ),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  color: Colors.black87,
                  child: Text(
                    status,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.green,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
