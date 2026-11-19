import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import 'pairing.dart';

/// Keeps the phone's pairing key between app starts.
class PairingStore {
  PairingStore._();

  static final PairingStore instance = PairingStore._();

  // Until load() finishes (or if the file cannot be used) the key lives in
  // memory only, and a new one is made each time the app starts.
  PairingKey _key = PairingKey.generate();

  PairingKey get key => _key;

  Future<File?> _file() async {
    try {
      final dir = await getApplicationSupportDirectory();

      return File('${dir.path}${Platform.pathSeparator}pairing_key.txt');
    } catch (e) {
      debugPrint('Pairing key file unavailable: $e');
      return null;
    }
  }

  Future<void> load() async {
    final file = await _file();

    try {
      if (file != null && await file.exists()) {
        final stored = PairingKey.parse(await file.readAsString());

        if (stored != null) {
          _key = stored;
          return;
        }
      }
    } catch (e) {
      debugPrint('Could not read the pairing key: $e');
    }

    await _save(file);
  }

  /// Makes a new key. The old one stops working for new connections.
  Future<void> regenerate() async {
    _key = PairingKey.generate();

    await _save(await _file());
  }

  Future<void> _save(File? file) async {
    if (file == null) return;

    try {
      await file.parent.create(recursive: true);
      await file.writeAsString(_key.display, flush: true);
    } catch (e) {
      debugPrint('Could not save the pairing key: $e');
    }
  }
}
