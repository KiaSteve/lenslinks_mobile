import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../camera/camera_service.dart';
import '../services/camera_stream_service.dart';
import '../networking/audio_server.dart';
import '../networking/pairing_store.dart';
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

  Future<void> _newKey() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text("Make a new key?"),
        content: const Text(
          "The Windows app will be disconnected and will need the new key.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text("Cancel"),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text("Make new key"),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await PairingStore.instance.regenerate();

    tcpServer.disconnectClient();
    AudioServer().disconnectClient();

    if (!mounted) return;

    setState(() {});
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
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        status,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.green,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        "Pairing key",
                        style: TextStyle(color: Colors.white70, fontSize: 14),
                      ),
                      Text(
                        PairingStore.instance.key.display,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                        ),
                      ),
                      const Text(
                        "Type this key into the LensLinks Windows app once",
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                      TextButton(
                        onPressed: _newKey,
                        child: const Text("Make a new key"),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
