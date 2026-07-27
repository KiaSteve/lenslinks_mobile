import 'package:flutter/material.dart';

import 'networking/udp_listener.dart';
import 'screens/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await UdpListener().start();

  runApp(const LensLinksMobileApp());
}

class LensLinksMobileApp extends StatelessWidget {
  const LensLinksMobileApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "LensLinks Mobile",
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        colorSchemeSeed: Colors.blue,
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}
