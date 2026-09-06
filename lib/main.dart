// main.dart — QuotiMate entry point with Google Auth & Cloud Sync Gate

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'app_state.dart';
import 'main_ui.dart';
import 'pages/sign_in_page.dart';
import 'services/auth_service.dart';
import 'services/cloud_sync_service.dart';
import 'services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase (safely catches when options/JSON not present on certain platforms)
  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint('Firebase initialization notice: $e');
  }

  // Initialize Core Services
  await NotificationService().init();
  debugPrint('Notification service initialized');
  await AuthService().init();
  await CloudSyncService().init();

  runApp(const QuotiMateApp());

  // Request the Android 13+ notification permission after the first frame so
  // the system dialog reliably shows with the app in the foreground.
  WidgetsBinding.instance.addPostFrameCallback((_) {
    NotificationService().requestPermissions();
  });
}

class QuotiMateApp extends StatelessWidget {
  const QuotiMateApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AppStateProvider(
      state: AppState(),
      child: MaterialApp(
        title: 'QuotiMate',
        debugShowCheckedModeBanner: false,
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
