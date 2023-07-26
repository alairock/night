// File generated by FlutterFire CLI.
// ignore_for_file: lines_longer_than_80_chars, avoid_classes_with_only_static_members
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your Firebase apps.
///
/// Example:
/// ```dart
/// import 'firebase_options.dart';
/// // ...
/// await Firebase.initializeApp(
///   options: DefaultFirebaseOptions.currentPlatform,
/// );
/// ```
class DefaultFirebaseOptions {
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
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for windows - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyANq5bvapFnY9TDf1U3KiRxCqevFmoF4pE',
    appId: '1:138719973250:web:67e8cff533a5682e4d099b',
    messagingSenderId: '138719973250',
    projectId: 'codafire-5ec47',
    authDomain: 'codafire-5ec47.firebaseapp.com',
    databaseURL: 'https://codafire-5ec47-default-rtdb.firebaseio.com',
    storageBucket: 'codafire-5ec47.appspot.com',
    measurementId: 'G-QFKQ8X3NMJ',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBzpQhSjpewGXWFUf4EW7mN29iumZIFnd0',
    appId: '1:138719973250:android:127ff165a817f1544d099b',
    messagingSenderId: '138719973250',
    projectId: 'codafire-5ec47',
    databaseURL: 'https://codafire-5ec47-default-rtdb.firebaseio.com',
    storageBucket: 'codafire-5ec47.appspot.com',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyBovp4K27kTCN_gK5csLmZIvV-YdDloA-o',
    appId: '1:138719973250:ios:bc7c141e140633184d099b',
    messagingSenderId: '138719973250',
    projectId: 'codafire-5ec47',
    databaseURL: 'https://codafire-5ec47-default-rtdb.firebaseio.com',
    storageBucket: 'codafire-5ec47.appspot.com',
    iosClientId: '138719973250-quppg9unvbpbeokgfkbtm640t4u2mb13.apps.googleusercontent.com',
    iosBundleId: 'com.example.mob',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyBovp4K27kTCN_gK5csLmZIvV-YdDloA-o',
    appId: '1:138719973250:ios:8d1af5ffb264091c4d099b',
    messagingSenderId: '138719973250',
    projectId: 'codafire-5ec47',
    databaseURL: 'https://codafire-5ec47-default-rtdb.firebaseio.com',
    storageBucket: 'codafire-5ec47.appspot.com',
    iosClientId: '138719973250-2ep3q2l253ktv0ndmmmn8cdrmo653v2a.apps.googleusercontent.com',
    iosBundleId: 'com.example.mob.RunnerTests',
  );
}
