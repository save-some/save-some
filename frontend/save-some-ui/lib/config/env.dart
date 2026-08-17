import 'dart:io' show Platform;

class Env {
  static String get apiBaseUrl {
    if (Platform.isAndroid) {
      // 10.2.2.2 is Android emulator's alias for the host machine.
      // A physical Android device needs your machine's LAN IP instead
      // (e.g. http://192.168.1.x:8000), since 10.0.2.2 only exists
      // inside the emulator's virtual network.
      return 'http://10.0.2.2:8000';
    }
    // iOS simulator and desktop can reach the host machine's localhost directly.
    return 'http://127.0.0.1:8000';
  }
}