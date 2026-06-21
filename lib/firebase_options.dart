import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      default:
        return android;
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyB5yJJashmVCZ0LWD9EuXt6gC-Cqja_n1E',
    appId: '1:762902718914:android:da108777df14f41653ce5b',
    messagingSenderId: '762902718914',
    projectId: 'soporte-bsm',
    storageBucket: 'soporte-bsm.firebasestorage.app',
  );

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyB5yJJashmVCZ0LWD9EuXt6gC-Cqja_n1E',
    appId: '1:762902718914:android:da108777df14f41653ce5b',
    messagingSenderId: '762902718914',
    projectId: 'soporte-bsm',
    storageBucket: 'soporte-bsm.firebasestorage.app',
  );
}
