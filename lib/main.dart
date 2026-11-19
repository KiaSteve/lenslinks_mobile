import 'package:flutter/material.dart';

import 'networking/audio_server.dart';
import 'networking/pairing_store.dart';
import 'networking/tcp_server.dart';
import 'networking/udp_listener.dart';
import 'screens/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load (or make) the pairing key before any connection can arrive.
  await PairingStore.instance.load();

  await UdpListener().start();
  await TcpServer().start();
  await AudioServer().start();

  runApp(const LensLinksMobileApp());
}

class LensLinksMobileApp extends StatelessWidget {
  const LensLinksMobileApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: "LensLinks Mobile",
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.blue,
        brightness: Brightness.dark,
      ),
      home: const HomeScreen(),
    );
  }
}
