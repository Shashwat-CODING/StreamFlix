import 'dart:io';
import 'package:flutter/material.dart';
import 'package:win32_registry/win32_registry.dart';

class WindowServiceWin {
  static Future<void> registerProtocol(String scheme) async {
    if (!Platform.isWindows) return;
    
    try {
      final appPath = Platform.resolvedExecutable;
      final protocolRegKey = 'Software\\Classes\\$scheme';
      
      // Register the protocol
      final regKey = Registry.currentUser.createKey(protocolRegKey);
      regKey.createValue(const RegistryValue(
        'URL Protocol',
        RegistryValueType.string,
        '',
      ));
      
      // Register the command to open the app
      final commandKey = regKey.createKey('shell\\open\\command');
      commandKey.createValue(RegistryValue(
        '',
        RegistryValueType.string,
        '"$appPath" "%1"',
      ));
      debugPrint('Windows: Protocol $scheme:// registered successfully.');
    } catch (e) {
      debugPrint('Windows: Failed to register protocol: $e');
    }
  }
}
