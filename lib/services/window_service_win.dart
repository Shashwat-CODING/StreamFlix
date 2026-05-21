import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:win32_registry/win32_registry.dart';

class WindowServiceWin {
  static Future<void> registerProtocol(String scheme) async {
    if (!Platform.isWindows) return;
    
    try {
      final appPath = Platform.resolvedExecutable;
      final protocolRegKey = 'Software\\Classes\\$scheme';
      
      // Register the protocol
      final regKey = CURRENT_USER.create(protocolRegKey);
      regKey.setValue('URL Protocol', const RegistryValue.string(''));
      
      // Register the command to open the app
      final commandKey = regKey.create('shell\\open\\command');
      commandKey.setValue('', RegistryValue.string('"$appPath" "%1"'));
      debugPrint('Windows: Protocol $scheme:// registered successfully.');
    } catch (e) {
      debugPrint('Windows: Failed to register protocol: $e');
    }
  }
}

