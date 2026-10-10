import 'package:flutter/material.dart';

import 'networking/tcp_server.dart';
import 'networking/udp_listener.dart';
import 'screens/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await UdpListener().start();
  await TcpServer().start();

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
