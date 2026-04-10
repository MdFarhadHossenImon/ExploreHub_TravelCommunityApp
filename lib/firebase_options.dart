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

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyBpsr6WxnfxaGYJ-bsZtq2FWhkFdep9z40',
    appId: '1:1047252780755:web:4eea92a9eb6628892d7626',
    messagingSenderId: '1047252780755',
    projectId: 'explorehubtravelcommunity',
    authDomain: 'explorehubtravelcommunity.firebaseapp.com',
    storageBucket: 'explorehubtravelcommunity.firebasestorage.app',
    measurementId: 'G-F7YRST5MWB',
  );

  // Replace this file by running `flutterfire configure`.

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBImWQijAKb1AwUPowD3gE9KiSUb0HhZzU',
    appId: '1:1047252780755:android:40e25958fa3db3e82d7626',
    messagingSenderId: '1047252780755',
    projectId: 'explorehubtravelcommunity',
    storageBucket: 'explorehubtravelcommunity.firebasestorage.app',
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
    apiKey: 'AIzaSyBpsr6WxnfxaGYJ-bsZtq2FWhkFdep9z40',
    appId: '1:1047252780755:web:bde04f670cc644f52d7626',
    messagingSenderId: '1047252780755',
    projectId: 'explorehubtravelcommunity',
    authDomain: 'explorehubtravelcommunity.firebaseapp.com',
    storageBucket: 'explorehubtravelcommunity.firebasestorage.app',
    measurementId: 'G-7RVNZQ1X2T',
  );

  static const FirebaseOptions linux = FirebaseOptions(
    apiKey: 'replace-me',
    appId: 'replace-me',
    messagingSenderId: 'replace-me',
    projectId: 'replace-me',
    storageBucket: 'replace-me',
  );
}