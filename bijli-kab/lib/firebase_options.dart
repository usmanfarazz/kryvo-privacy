import 'package:firebase_core/firebase_core.dart';

/// Firebase project settings.
///
/// Until these are filled in, Bijli Kab? runs in **demo mode** (simulated
/// neighbours, everything stays on the phone). To go live, either run
/// `flutterfire configure` (it overwrites this file) or paste the values from
/// Firebase console → Project settings → Your apps → Android app.
/// See README.md → "Going live with Firebase".
class DefaultFirebaseOptions {
  static const android = FirebaseOptions(
    apiKey: 'YOUR_API_KEY',
    appId: 'YOUR_APP_ID',
    messagingSenderId: 'YOUR_SENDER_ID',
    projectId: 'YOUR_PROJECT_ID',
    storageBucket: 'YOUR_PROJECT_ID.appspot.com',
  );

  static FirebaseOptions get currentPlatform => android;

  static bool get isConfigured => !android.apiKey.startsWith('YOUR_');
}
