// app_env.dart — keys injected at build time from the gitignored `.env` file
// via `--dart-define-from-file=.env` (see tool/build_release.sh).
//
// Values are compiled into the binary. They are identifiers, not secrets that
// can be hidden from a determined user of the distributed APK — restrict them
// in the provider console rather than relying on them staying private.

class AppEnv {
  static const String groqApiKey = String.fromEnvironment('GROQ_API_KEY');
  static const String firebaseApiKey = String.fromEnvironment('FIREBASE_API_KEY');
  static const String firebaseProjectId =
      String.fromEnvironment('FIREBASE_PROJECT_ID', defaultValue: 'quotimate-cloud');

  static bool get hasGroqKey => groqApiKey.isNotEmpty;

  /// The browser review page can only write signatures straight to Firestore
  /// when a Web API key is available; otherwise the local review server is the
  /// only delivery path.
  static bool get canWriteSignatureToCloud => firebaseApiKey.isNotEmpty;
}
