import 'package:flutter/material.dart';

import '../services/discovery_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final DiscoveryService discovery = DiscoveryService();

  @override
  void initState() {
    super.initState();
    discovery.start();
  }

  @override
  void dispose() {
    discovery.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("LensLinks Mobile")),
      body: const Center(
        child: Text("Waiting for desktop...", style: TextStyle(fontSize: 20)),
      ),
    );
  }
}
