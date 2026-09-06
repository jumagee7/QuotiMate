// pages/sign_in_page.dart — QuotiMate Google Sign-In & Authentication Page
// Beautiful dark-gold themed authentication UI matching QuotiMate design tokens.

import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../app_state.dart';
import '../main_ui.dart';

class SignInPage extends StatefulWidget {
  final VoidCallback? onSignedIn;

  const SignInPage({super.key, this.onSignedIn});

  @override
  State<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends State<SignInPage> with SingleTickerProviderStateMixin {
  bool _isLoading = false;
  String? _errorMessage;
  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  // ─── Theme Colors ─────────────────────────────────────────────────────────
  static const _bg        = Color(0xFF0B0E17);
  static const _surface   = Color(0xFF161B26);
  static const _surface2  = Color(0xFF1C2233);
  static const _border    = Color(0xFF2A3045);
  static const _gold      = Color(0xFFFFC107);
  static const _goldLight = Color(0xFFE7C67B);
  static const _white70   = Color(0xFFB0B8D0);
  static const _white38   = Color(0xFF616C88);

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic));

    _animCtrl.forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  void _navigateToHome() {
    if (!mounted) return;
    widget.onSignedIn?.call();
    Navigator.of(context).pushAndRemoveUntil(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => const QuotiMateShell(),
        transitionDuration: const Duration(milliseconds: 600),
        transitionsBuilder: (context, animation, secondaryAnimation, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
      (route) => false,
    );
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final user = await AuthService().signInWithGoogle();
      if (!mounted) return;

      if (user != null) {
        final appState = AppStateProvider.of(context);
        appState.updateUserProfile(
          name: user.name,
          email: user.email,
        );
        // Restart cloud sync listeners now that the user is authenticated
        appState.restartCloudSync();
        _navigateToHome();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Sign in failed: ${e.toString().replaceAll('Exception:', '').trim()}';
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleGuestSignIn() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final user = await AuthService().signInAsGuest();
      if (!mounted) return;

      final appState = AppStateProvider.of(context);
      appState.updateUserProfile(
        name: user.name,
        email: user.email,
      );
      _navigateToHome();
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width > 800;

    return Scaffold(
      backgroundColor: _bg,
      body: Stack(
        children: [
          // Background ambient gradient glow
          Positioned(
            top: -100,
            left: -100,
            child: Container(
              width: 400,
              height: 400,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    _gold.withValues(alpha: 0.08),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -120,
            right: -100,
            child: Container(
              width: 500,
              height: 500,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF1E3A8A).withValues(alpha: 0.12),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // Main Content
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
              child: FadeTransition(
                opacity: _fadeAnim,
                child: SlideTransition(
                  position: _slideAnim,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: isDesktop ? 860 : 440,
                    ),
                    child: isDesktop ? _buildDesktopLayout() : _buildMobileLayout(),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Desktop 2-Column Card Layout ───────────────────────────────────────────
  Widget _buildDesktopLayout() {
    return Container(
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 40,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Left Hero Banner
            Expanded(
              flex: 5,
              child: Container(
                padding: const EdgeInsets.all(40),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF0F162C),
                      Color(0xFF161B26),
                    ],
                  ),
                  border: Border(right: BorderSide(color: _border)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Logo
                        Image.asset(
                          'assets/logo2.png',
                          width: 170,
                          filterQuality: FilterQuality.high,
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          'Enterprise Quotations &\nProject Management',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            height: 1.25,
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Save your quotations, sequential numbers, invoices, clients, and meetings online for free with Google Cloud Sync.',
                          style: TextStyle(
                            color: _white70,
                            fontSize: 13,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    // Feature List
                    Column(
                      children: [
                        _buildFeatureItem(
                          icon: Icons.cloud_sync_outlined,
                          title: 'Free Online Cloud Sync',
                          subtitle: 'Automatic multi-device synchronization',
                        ),
                        const SizedBox(height: 14),
                        _buildFeatureItem(
                          icon: Icons.tag_outlined,
                          title: 'Centralized Quote Numbers',
                          subtitle: 'Sequential quotation numbering across team',
                        ),
                        const SizedBox(height: 14),
                        _buildFeatureItem(
                          icon: Icons.calendar_month_outlined,
                          title: 'Meetings & Schedule Tracker',
                          subtitle: 'Integrated client agenda & task reminders',
                        ),
                        const SizedBox(height: 14),
                        _buildFeatureItem(
                          icon: Icons.picture_as_pdf_outlined,
                          title: 'Instant PDF Generation',
                          subtitle: 'Regenerate branded PDFs anytime, anywhere',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Right Sign-In Form Area
            Expanded(
              flex: 4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 44),
                color: _surface,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Welcome to QuotiMate',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Sign in with your Google account to access your shared company workspace.',
                      style: TextStyle(
                        color: _white38,
                        fontSize: 12,
                        height: 1.4,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),

                    if (_errorMessage != null) ...[
                      _buildErrorBanner(_errorMessage!),
                      const SizedBox(height: 20),
                    ],

                    _buildGoogleSignInButton(),
                    const SizedBox(height: 16),
                    _buildGuestOption(),

                    const SizedBox(height: 32),
                    const Divider(color: _border),
                    const SizedBox(height: 16),

                    const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.lock_outline, color: _white38, size: 14),
                        SizedBox(width: 6),
                        Text(
                          'Secure end-to-end cloud persistence',
                          style: TextStyle(color: _white38, fontSize: 11),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Mobile Single Column Card Layout ───────────────────────────────────────
  Widget _buildMobileLayout() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 30,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Logo & Title
          Center(
            child: Image.asset(
              'assets/logo2.png',
              width: 180,
              filterQuality: FilterQuality.high,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Quotation & Project Cloud',
            style: TextStyle(
              color: Colors.white,
              fontSize: 19,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Text(
            'Sign in to synchronize quotes, invoices, schedules, and team numbers online for free.',
            style: TextStyle(
              color: _white70,
              fontSize: 12,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 28),

          // Features Summary
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _surface2,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _border),
            ),
            child: Column(
              children: [
                _buildCompactFeature(Icons.cloud_sync, 'Free Realtime Cloud Sync'),
                const SizedBox(height: 8),
                _buildCompactFeature(Icons.tag, 'Shared Sequential Quote Numbers'),
                const SizedBox(height: 8),
                _buildCompactFeature(Icons.calendar_month, 'Schedules, Meetings & Tasks'),
              ],
            ),
          ),
          const SizedBox(height: 28),

          if (_errorMessage != null) ...[
            _buildErrorBanner(_errorMessage!),
            const SizedBox(height: 16),
          ],

          _buildGoogleSignInButton(),
          const SizedBox(height: 14),
          _buildGuestOption(),

          const SizedBox(height: 24),
          const Divider(color: _border),
          const SizedBox(height: 12),
          const Center(
            child: Text(
              'Free Cloud Storage powered by Firebase',
              style: TextStyle(color: _white38, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }

  // ── Components ─────────────────────────────────────────────────────────────
  Widget _buildGoogleSignInButton() {
    return Container(
      height: 50,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: const LinearGradient(
          colors: [
            Color(0xFF1E2638),
            Color(0xFF181F2F),
          ],
        ),
        border: Border.all(color: _gold.withValues(alpha: 0.6), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: _gold.withValues(alpha: 0.12),
            blurRadius: 16,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: _isLoading ? null : _handleGoogleSignIn,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_isLoading)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(_gold),
                    ),
                  )
                else ...[
                  // Google "G" Icon representation
                  _buildGoogleIcon(),
                  const SizedBox(width: 14),
                  const Text(
                    'Continue with Google',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGoogleIcon() {
    return Container(
      width: 26,
      height: 26,
      decoration: const BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
      ),
      padding: const EdgeInsets.all(4),
      child: Center(
        child: Text(
          'G',
          style: TextStyle(
            color: const Color(0xFF4285F4),
            fontSize: 15,
            fontWeight: FontWeight.w900,
            fontFamily: 'Roboto',
          ),
        ),
      ),
    );
  }

  Widget _buildGuestOption() {
    return TextButton(
      onPressed: _isLoading ? null : _handleGuestSignIn,
      style: TextButton.styleFrom(
        foregroundColor: _white70,
        padding: const EdgeInsets.symmetric(vertical: 10),
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Explore Local Workspace',
            style: TextStyle(fontSize: 13, decoration: TextDecoration.underline),
          ),
          SizedBox(width: 4),
          Icon(Icons.arrow_forward, size: 14),
        ],
      ),
    );
  }

  Widget _buildFeatureItem({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            color: _gold.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _gold.withValues(alpha: 0.3)),
          ),
          child: Icon(icon, color: _goldLight, size: 18),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                subtitle,
                style: const TextStyle(
                  color: _white38,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCompactFeature(IconData icon, String title) {
    return Row(
      children: [
        Icon(icon, color: _gold, size: 16),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(color: _white70, fontSize: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorBanner(String message) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.red.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.redAccent, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: Colors.redAccent, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
