import 'package:flutter/cupertino.dart';
import 'package:window_manager/window_manager.dart';
import 'package:win32_registry/win32_registry.dart';
import 'dart:io';

class WindowService {
  static Future<void> init() async {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      await windowManager.ensureInitialized();
      WindowOptions windowOptions = const WindowOptions(
        size: Size(1280, 800),
        minimumSize: Size(1000, 600),
        center: true,
        backgroundColor: CupertinoColors.transparent,
        skipTaskbar: false,
        titleBarStyle: TitleBarStyle.normal,
        title: "Luxa",
      );
      windowManager.waitUntilReadyToShow(windowOptions, () async {
        await windowManager.show();
        await windowManager.focus();
      });

      if (Platform.isWindows) {
        await _registerProtocol('luxa');
      }
    }
  }

  static Future<void> _registerProtocol(String scheme) async {
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

