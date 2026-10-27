// main.dart — QuotiMate entry point with Google Auth & Cloud Sync Gate

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'app_state.dart';
import 'main_ui.dart';
import 'pages/sign_in_page.dart';
import 'services/auth_service.dart';
import 'services/cloud_sync_service.dart';
import 'services/notification_service.dart';

/// Background notification response handler.
///
/// Must be a TOP-LEVEL function in the app's entry-point file (main.dart) and
/// carry `@pragma('vm:entry-point')`. When the app is backgrounded or killed,
/// flutter_local_notifications spins up a fresh Dart isolate rooted at main()
/// and invokes this function. Without it, scheduled alarms are delivered to
/// the Android tray but Dart never wakes up to handle actions or taps.
@pragma('vm:entry-point')
void _notificationBackgroundHandler(NotificationResponse response) {
  // Background isolate — no widget tree, no app state.
  // Payloads are re-read by the foreground shell when the user opens the app.
  debugPrint('[BG] notification id=${response.id} '
      'action=${response.actionId} payload=${response.payload}');
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase (safely catches when options/JSON not present on certain platforms)
  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint('Firebase initialization notice: $e');
  }

  // Initialize Core Services
  await NotificationService().init(onBackground: _notificationBackgroundHandler);

  debugPrint(NotificationService().initError == null
      ? 'Notification service initialized'
      : 'Notification service DOWN: ${NotificationService().initError}');
  await AuthService().init();
  await CloudSyncService().init();

  runApp(const QuotiMateApp());

  // Request the Android 13+ notification permission after the first frame so
  // the system dialog reliably shows with the app in the foreground.
  WidgetsBinding.instance.addPostFrameCallback((_) {
    NotificationService().requestPermissions();
  });
}

class QuotiMateApp extends StatefulWidget {
  const QuotiMateApp({super.key});

  @override
  State<QuotiMateApp> createState() => _QuotiMateAppState();
}

class _QuotiMateAppState extends State<QuotiMateApp> {
  final AppState _state = AppState();

  @override
  void dispose() {
    // AppState owns the schedule ticker; without this it outlives the tree.
    _state.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppStateProvider(
      state: _state,
      child: MaterialApp(
        title: 'QuotiMate',
        debugShowCheckedModeBanner: false,
        navigatorKey: appNavigatorKey,
        scaffoldMessengerKey: rootMessengerKey,
        theme: ThemeData(
          useMaterial3: true,
          fontFamily: 'Roboto',
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFFFFC107),
            brightness: Brightness.dark,
          ),
          scaffoldBackgroundColor: const Color(0xFF0B0E17),
        ),
        home: const _SplashScreen(),
      ),
    );
  }
}

class _SplashScreen extends StatefulWidget {
  const _SplashScreen();
  @override
  State<_SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<_SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fade;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeIn);
    _ctrl.forward();

    _timer = Timer(const Duration(milliseconds: 2200), () {
      if (!mounted) return;

      final isAuthenticated = AuthService().isAuthenticated;

      Widget targetPage;
      if (isAuthenticated) {
        targetPage = const QuotiMateShell();
      } else {
        targetPage = const SignInPage();
      }

      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => targetPage,
          transitionDuration: const Duration(milliseconds: 600),
          transitionsBuilder: (context, animation, secondaryAnimation, child) =>
              FadeTransition(opacity: animation, child: child),
        ),
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0E17),
      body: Center(
        child: FadeTransition(
          opacity: _fade,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(
                'assets/logo2.png',
                width: 220,
                filterQuality: FilterQuality.high,
              ),
              const SizedBox(height: 32),
              const SizedBox(
                width: 32,
                height: 32,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFE7C67B)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
