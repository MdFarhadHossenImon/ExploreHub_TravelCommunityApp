import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  const DefaultFirebaseOptions._();

  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        return windows;
      case TargetPlatform.linux:
        return linux;
      default:
        throw UnsupportedError('Firebase is not configured for this platform.');
    }
  }

  // Replace this file by running `flutterfire configure`.
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'replace-me',
    appId: 'replace-me',
    messagingSenderId: 'replace-me',
    projectId: 'replace-me',
    authDomain: 'replace-me',
    storageBucket: 'replace-me',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'replace-me',
    appId: 'replace-me',
    messagingSenderId: 'replace-me',
    projectId: 'replace-me',
    storageBucket: 'replace-me',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'replace-me',
    appId: 'replace-me',
    messagingSenderId: 'replace-me',
    projectId: 'replace-me',
    iosBundleId: 'com.example.explorehubFlutter',
    storageBucket: 'replace-me',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'replace-me',
    appId: 'replace-me',
    messagingSenderId: 'replace-me',
    projectId: 'replace-me',
    iosBundleId: 'com.example.explorehubFlutter',
    storageBucket: 'replace-me',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'replace-me',
    appId: 'replace-me',
    messagingSenderId: 'replace-me',
    projectId: 'replace-me',
    storageBucket: 'replace-me',
  );

  static const FirebaseOptions linux = FirebaseOptions(
    apiKey: 'replace-me',
    appId: 'replace-me',
    messagingSenderId: 'replace-me',
    projectId: 'replace-me',
    storageBucket: 'replace-me',
  );
}
