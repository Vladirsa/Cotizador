// lib/firebase_options.dart
// HETNA CNC — Configuración de Firebase
// Generado automáticamente con los datos del google-services.json
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      default:
        return android;
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDF1N0m_tHOALq_HhhEw5KTwQsMyS9-4Oc',
    appId: '1:712831510742:android:d75fc61c481dc3218bc177',
    messagingSenderId: '712831510742',
    projectId: 'hetna-cnc',
    storageBucket: 'hetna-cnc.firebasestorage.app',
  );
}
