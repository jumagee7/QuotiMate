// main_ui.dart â€” QuotiMate App Shell (Sidebar + Router)

import 'package:flutter/material.dart';

// Pages
import 'pages/dashboard_page.dart';
import 'pages/quotes_page.dart';
import 'pages/clients_page.dart';
import 'pages/products_page.dart';
import 'pages/invoices_page.dart';
import 'pages/projects_page.dart';
import 'pages/settings_page.dart';
import 'pages/schedule_page.dart';
import 'pages/sign_in_page.dart';
import 'services/auth_service.dart';
import 'services/cloud_sync_service.dart';
import 'app_state.dart';
import 'models.dart';

class QuotiMateShell extends StatefulWidget {
  const QuotiMateShell({super.key});

  @override
  State<QuotiMateShell> createState() => _QuotiMateShellState();
}

class _QuotiMateShellState extends State<QuotiMateShell> {
  bool _collapsed = false;
  int _selectedNav = 0;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  void _navigateTo(int idx, {bool openCreate = false}) {
    setState(() => _selectedNav = idx);
    // openCreate is passed to individual pages that support it
    // Currently used as a signal; actual dialog triggering is done via GlobalKeys or state
  }

  @override
  Widget build(BuildContext context) {
    final appState = AppStateProvider.of(context);
    final isDesktop = MediaQuery.of(context).size.width >= 800;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFF0B0E17),
      bottomNavigationBar: isDesktop ? null : SafeArea(
        child: Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF161B26),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFF2A3045)),
            boxShadow: const [
              BoxShadow(color: Colors.black38, blurRadius: 24, offset: Offset(0, 8)),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildModernMobileNavItem(Icons.dashboard_rounded, 'Home', 0),
              _buildModernMobileNavItem(Icons.article_rounded, 'Quotes', 1),
              _buildModernMobileNavItem(Icons.business_center_rounded, 'Projects', 7),
              _buildModernMobileNavItem(Icons.people_rounded, 'Clients', 2),
              _buildMoreNavItem(),
            ],
          ),
        ),
      ),
      body: SafeArea(
        child: Row(
          children: [
            // â”€â”€ Sidebar â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
            if (isDesktop) _buildSidebar(context, appState, isDrawer: false),

            // â”€â”€ Main Area â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
            Expanded(
              child: Padding(
                padding: EdgeInsets.all(isDesktop ? 24.0 : 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top Bar
                    _buildTopBar(appState, isDesktop),
                    SizedBox(height: isDesktop ? 24 : 16),

                    // Active Page
                    Expanded(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        child: _getPage(_selectedNav),
                      ),
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

  Widget _buildSidebar(BuildContext context, AppState appState, {required bool isDrawer}) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 240),
      width: (!isDrawer && _collapsed) ? 72 : 260,
      color: const Color(0xFF0F162C),
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
      child: Column(
        children: [
          // Brand + collapse button
          Row(
            children: [
              if (isDrawer || !_collapsed)
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFC107).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Image.asset('assets/logo2.png', width: 24, height: 24),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'QuotiMate',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              height: 0.95,
                            ),
                      ),
                    ],
                  ),
                ),
              if (!isDrawer)
                IconButton(
                  onPressed: () => setState(() => _collapsed = !_collapsed),
                  icon: Icon(
                    _collapsed ? Icons.chevron_right : Icons.chevron_left,
                    color: const Color(0xFFFFC107),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 24),

          // Navigation Links
          Expanded(
            child: ListView(
              children: [
                _navCard(icon: Icons.dashboard, label: 'Dashboard', idx: 0, isDrawer: isDrawer),
                const SizedBox(height: 8),
                _navCard(icon: Icons.article, label: 'Quotes', idx: 1, isDrawer: isDrawer),
                const SizedBox(height: 8),
                _navCard(icon: Icons.receipt_long, label: 'Invoices', idx: 4, isDrawer: isDrawer),
                const SizedBox(height: 8),
                _navCard(icon: Icons.business_center_rounded, label: 'Projects', idx: 7, isDrawer: isDrawer),
                const SizedBox(height: 8),
                _navCard(icon: Icons.people, label: 'Clients', idx: 2, isDrawer: isDrawer),
                const SizedBox(height: 8),
                _navCard(icon: Icons.inventory_2, label: 'Items', idx: 3, isDrawer: isDrawer),
                const SizedBox(height: 8),
                _navCard(icon: Icons.calendar_month, label: 'Schedule', idx: 6, isDrawer: isDrawer),
                const SizedBox(height: 8),
                _navCard(icon: Icons.settings, label: 'Settings', idx: 5, isDrawer: isDrawer),
              ],
            ),
          ),

          // User Profile Preview
          if (isDrawer || !_collapsed) ...[
            const Divider(color: Colors.white12),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () {
                if (isDrawer) Navigator.pop(context); // close drawer
                _showSignInDialog(context, appState);
              },
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: const Color(0xFFFFC107).withValues(alpha: 0.15),
                    child: appState.userName.isNotEmpty
                        ? Text(
                            appState.userName[0].toUpperCase(),
                            style: const TextStyle(color: Color(0xFFFFC107), fontWeight: FontWeight.bold),
                          )
                        : const Icon(Icons.person, color: Color(0xFFFFC107), size: 18),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          appState.userName.isNotEmpty ? appState.userName : 'Sign In',
                          style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          appState.userRole,
                          style: const TextStyle(color: Colors.white38, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.edit_outlined, color: Colors.white24, size: 14),
                ],
              ),
            ),
          ],

          // App Version
          const SizedBox(height: 10),
          Text(
            'v1.0.0',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white54),
          ),
        ],
      ),
    );
  }

  // ————————————————————————————————————————————————————————————————————————————

  Widget _getPage(int idx) {
    switch (idx) {
      case 0: return DashboardPage(key: const ValueKey('dashboard'), onNavigate: _navigateTo);
      case 1: return const QuotesPage(key: ValueKey('quotes'));
      case 2: return const ClientsPage(key: ValueKey('clients'));
      case 3: return const ProductsPage(key: ValueKey('products'));
      case 4: return const InvoicesPage(key: ValueKey('invoices'));
      case 5: return const SettingsPage(key: ValueKey('settings'));
      case 6: return const SchedulePage(key: ValueKey('schedule'));
      case 7: return const ProjectsPage(key: ValueKey('projects'));
      default: return const DashboardPage();
    }
  }

  String _getPageTitle(int idx) {
    switch (idx) {
      case 0:
        final hour = DateTime.now().hour;
        final greeting = hour < 12
            ? 'Good morning'
            : hour < 17
                ? 'Good afternoon'
                : 'Good evening';
        final name = AppStateProvider.of(context).userName.trim();
        return name.isNotEmpty ? '$greeting, $name' : greeting;
      case 1: return 'Quotes Management';
      case 2: return 'Clients Directory';
      case 3: return 'Products & Services';
      case 4: return 'Invoices & Billing';
      case 5: return 'Application Settings';
      case 6: return 'Schedule & Tasks';
      case 7: return 'Projects & QuickBook';
      default: return '';
    }
  }

  String _getPageSubtitle(int idx) {
    switch (idx) {
      case 0: return 'Quotation overview for today';
      case 1: return 'Create, manage and track quotations';
      case 2: return 'Manage your client directory';
      case 3: return 'Products, services and pricing';
      case 4: return 'Track invoices and payments';
      case 5: return 'Configure your app preferences';
      case 6: return 'Tasks, events and appointments';
      default: return 'QuotiMate - Make Quotations Faster';
    }
  }

  Widget _navCard({required IconData icon, required String label, required int idx, bool isDrawer = false}) {
    final bool selected = _selectedNav == idx;
    return GestureDetector(
      onTap: () {
        setState(() => _selectedNav = idx);
        if (isDrawer) {
          Navigator.pop(context); // Close drawer
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFFFC107) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          child: Row(
            children: [
              Icon(
                icon,
                color: selected ? Colors.black : const Color(0xFFFFC107),
                size: 20,
              ),
              if (isDrawer || !_collapsed) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: selected ? Colors.black : Colors.white70,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
                if (selected)
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.black38),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModernMobileNavItem(IconData icon, String label, int targetIdx) {
    final selected = _selectedNav == targetIdx;
    return Expanded(
      child: GestureDetector(
        onTap: () => _navigateTo(targetIdx),
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 240),
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFFFC107).withValues(alpha: 0.15) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: selected ? const Color(0xFFFFC107) : Colors.white54,
                size: 22,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: selected ? const Color(0xFFFFC107) : Colors.white54,
                  fontSize: 10,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMoreNavItem() {
    final moreSelected = [3, 4, 5, 6].contains(_selectedNav);
    return Expanded(
      child: GestureDetector(
        onTap: () => _showMoreSheet(),
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 240),
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
          decoration: BoxDecoration(
            color: moreSelected ? const Color(0xFFFFC107).withValues(alpha: 0.15) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.grid_view_rounded,
                color: moreSelected ? const Color(0xFFFFC107) : Colors.white54,
                size: 22,
              ),
              const SizedBox(height: 4),
              Text(
                'More',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: moreSelected ? const Color(0xFFFFC107) : Colors.white54,
                  fontSize: 10,
                  fontWeight: moreSelected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showMoreSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        decoration: const BoxDecoration(
          color: Color(0xFF161B26),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          border: Border(
            top: BorderSide(color: Color(0xFF2A3045)),
            left: BorderSide(color: Color(0xFF2A3045)),
            right: BorderSide(color: Color(0xFF2A3045)),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 36, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 20),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text('More', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 16),
            _moreSheetItem(Icons.receipt_long_rounded, 'Invoices', 'Track invoices and payments', 4, const Color(0xFF34D399)),
            const SizedBox(height: 8),
            _moreSheetItem(Icons.inventory_2_rounded, 'Products & Items', 'Manage your item catalog', 3, const Color(0xFFFFC107)),
            const SizedBox(height: 8),
            _moreSheetItem(Icons.calendar_month_rounded, 'Schedule & Tasks', 'Appointments and reminders', 6, Colors.blue),
            const SizedBox(height: 8),
            _moreSheetItem(Icons.settings_rounded, 'Settings', 'App preferences and profile', 5, Colors.green),
          ],
        ),
      ),
    );
  }

  Widget _moreSheetItem(IconData icon, String title, String subtitle, int idx, Color color) {
    final selected = _selectedNav == idx;
    return GestureDetector(
      onTap: () {
        Navigator.pop(context);
        setState(() => _selectedNav = idx);
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.12) : const Color(0xFF1E2538),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: selected ? color.withValues(alpha: 0.4) : const Color(0xFF2A3045)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
                Text(subtitle, style: const TextStyle(color: Color(0xFF8A92A6), fontSize: 12)),
              ],
            )),
            Icon(Icons.chevron_right, color: Colors.white38, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(AppState appState, bool isDesktop) {
    final unread = appState.unreadCount;

    return Row(
      children: [
        // Title Area
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _getPageTitle(_selectedNav),
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      fontSize: isDesktop ? null : 20,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                _getPageSubtitle(_selectedNav),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white54,
                  fontSize: isDesktop ? null : 12,
                ),
              ),
            ],
          ),
        ),

        // Cloud Sync Status Badge
        AnimatedBuilder(
          animation: CloudSyncService(),
          builder: (context, _) {
            final status = CloudSyncService().status;
            final isSynced = status == SyncStatus.synced;
            final isSyncing = status == SyncStatus.syncing;
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: isSynced
                    ? Colors.green.withValues(alpha: 0.12)
                    : (isSyncing ? const Color(0xFFFFC107).withValues(alpha: 0.12) : const Color(0xFF1E2538)),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSynced
                      ? Colors.green.withValues(alpha: 0.3)
                      : (isSyncing ? const Color(0xFFFFC107).withValues(alpha: 0.3) : const Color(0xFF2A3045)),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isSynced
                          ? Colors.greenAccent
                          : (isSyncing ? const Color(0xFFFFC107) : Colors.grey),
                    ),
                  ),
                  if (isDesktop) ...[
                    const SizedBox(width: 6),
                    Text(
                      CloudSyncService().statusMessage,
                      style: TextStyle(
                        color: isSynced
                            ? Colors.greenAccent
                            : (isSyncing ? const Color(0xFFFFC107) : const Color(0xFFB0B8D0)),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        ),
        const SizedBox(width: 8),

        // Notifications Bell
        Stack(
          children: [
            Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(30),
                onTap: () => _showNotificationPanel(context, appState),
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Icon(
                    unread > 0 ? Icons.notifications_active : Icons.notifications_outlined,
                    color: unread > 0 ? const Color(0xFFFFC107) : Colors.white70,
                    size: 24,
                  ),
                ),
              ),
            ),
            if (unread > 0)
              Positioned(
                right: 4,
                top: 4,
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFFFFC107)),
                  child: Text('$unread', style: const TextStyle(color: Colors.black, fontSize: 9, fontWeight: FontWeight.bold)),
                ),
              ),
          ],
        ),
        const SizedBox(width: 8),

        // User Avatar
        GestureDetector(
          onTap: () => _showSignInDialog(context, appState),
          child: Tooltip(
            message: appState.userName.isNotEmpty ? '${appState.userName} — ${appState.userRole}' : 'Profile & Account',
            child: CircleAvatar(
              radius: 20,
              backgroundColor: const Color(0xFFFFC107).withValues(alpha: 0.15),
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFFFC107).withValues(alpha: 0.4), width: 1.5),
                ),
                child: Center(
                  child: appState.userName.isNotEmpty
                      ? Text(
                          appState.userName[0].toUpperCase(),
                          style: const TextStyle(color: Color(0xFFFFC107), fontWeight: FontWeight.bold, fontSize: 16),
                        )
                      : const Icon(Icons.person, color: Color(0xFFFFC107), size: 20),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── User Account & Profile Dialog ──────────────────────────────────────────

  void _showSignInDialog(BuildContext context, AppState appState) {
    final nameCtrl = TextEditingController(text: appState.userName);
    final emailCtrl = TextEditingController(text: appState.userEmail);
    String role = appState.userRole.isNotEmpty ? appState.userRole : 'Admin';
    final user = AuthService().currentUser;
    final isGuest = user?.isGuest ?? (appState.userEmail.isEmpty || appState.userEmail.endsWith('.local'));

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF0F162C),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: Color(0xFF2A3045)),
          ),
          contentPadding: EdgeInsets.zero,
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: const BoxDecoration(
                    color: Color(0xFF19233E),
                    borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: const Color(0xFFFFC107).withValues(alpha: 0.15),
                        child: appState.userName.isNotEmpty
                            ? Text(appState.userName[0].toUpperCase(), style: const TextStyle(color: Color(0xFFFFC107), fontWeight: FontWeight.bold, fontSize: 22))
                            : const Icon(Icons.person, color: Color(0xFFFFC107), size: 28),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              appState.userName.isNotEmpty ? appState.userName : 'QuotiMate Member',
                              style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              appState.userEmail.isNotEmpty ? appState.userEmail : (isGuest ? 'Local Session' : 'Google Account'),
                              style: const TextStyle(color: Color(0xFFB0B8D0), fontSize: 12),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Form
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      _signInField('Full Name', nameCtrl, Icons.person_outline),
                      const SizedBox(height: 14),
                      _signInField('Email Address', emailCtrl, Icons.email_outlined),
                      const SizedBox(height: 14),
                      DropdownButtonFormField<String>(
                        initialValue: role,
                        dropdownColor: const Color(0xFF19233E),
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'Role',
                          labelStyle: const TextStyle(color: Colors.white70),
                          prefixIcon: const Icon(Icons.badge_outlined, color: Colors.white38, size: 20),
                          enabledBorder: const OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF2A3045))),
                          focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: Color(0xFFFFC107))),
                          filled: true,
                          fillColor: Colors.white.withValues(alpha: 0.04),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'Admin', child: Text('Admin')),
                          DropdownMenuItem(value: 'Sales Rep', child: Text('Sales Rep')),
                          DropdownMenuItem(value: 'Manager', child: Text('Manager')),
                          DropdownMenuItem(value: 'Viewer', child: Text('Viewer')),
                        ],
                        onChanged: (v) { if (v != null) setDialogState(() => role = v); },
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () {
                            appState.updateUserProfile(
                              name: nameCtrl.text.trim(),
                              email: emailCtrl.text.trim(),
                              role: role,
                            );
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Saved profile for ${nameCtrl.text.trim()}'),
                                backgroundColor: const Color(0xFF161B26),
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFFC107),
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('Save Profile', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Sign Out button
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            Navigator.pop(ctx);
                            await AuthService().signOut();
                            if (context.mounted) {
                              Navigator.of(context).pushAndRemoveUntil(
                                MaterialPageRoute(
                                  builder: (_) => SignInPage(onSignedIn: () {}),
                                ),
                                (route) => false,
                              );
                            }
                          },
                          icon: const Icon(Icons.logout, size: 16, color: Colors.redAccent),
                          label: const Text('Sign Out / Switch Account', style: TextStyle(color: Colors.redAccent)),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: Colors.redAccent.withValues(alpha: 0.5)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _signInField(String label, TextEditingController ctrl, IconData icon) {
    return TextField(
      controller: ctrl,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white70),
        prefixIcon: Icon(icon, color: Colors.white38, size: 20),
        enabledBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
        focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: Color(0xFFFFC107))),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.04),
      ),
    );
  }

  // â”€â”€ Notification Panel â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  void _showNotificationPanel(BuildContext context, AppState appState) {
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF0F162C),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          contentPadding: EdgeInsets.zero,
          content: SizedBox(
            width: 420,
            height: 480,
            child: Column(
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  decoration: const BoxDecoration(
                    color: Color(0xFF19233E),
                    borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.notifications_outlined, color: Color(0xFFFFC107), size: 20),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text('Notifications', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                      if (appState.unreadCount > 0)
                        TextButton(
                          onPressed: () {
                            appState.markAllNotificationsRead();
                            setDialogState(() {});
                          },
                          style: TextButton.styleFrom(foregroundColor: const Color(0xFFFFC107)),
                          child: const Text('Mark all read', style: TextStyle(fontSize: 12)),
                        ),
                    ],
                  ),
                ),

                // List
                Expanded(
                  child: appState.notifications.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.notifications_off_outlined, color: Colors.white12, size: 48),
                              const SizedBox(height: 12),
                              const Text('No notifications', style: TextStyle(color: Colors.white38, fontSize: 15)),
                            ],
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(12),
                          itemCount: appState.notifications.length,
                          separatorBuilder: (context, index) => const SizedBox(height: 6),
                          itemBuilder: (_, i) {
                            final n = appState.notifications[i];
                            return _NotificationTile(notification: n);
                          },
                        ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close', style: TextStyle(color: Colors.white54)),
            ),
          ],
        ),
      ),
    );
  }
}

// â”€â”€ Notification Tile â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _NotificationTile extends StatelessWidget {
  final AppNotification notification;
  const _NotificationTile({required this.notification});

  @override
  Widget build(BuildContext context) {
    final state = AppStateProvider.of(context);
    return GestureDetector(
      onTap: () {
        if (!notification.isRead) {
          notification.isRead = true;
          state.markNotificationRead(notification.id);
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: notification.isRead ? Colors.transparent : const Color(0xFF19233E),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: notification.isRead ? Colors.white10 : notification.color.withValues(alpha: 0.2),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: notification.color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(notification.icon, color: notification.color, size: 16),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          notification.title,
                          style: TextStyle(
                            color: notification.isRead ? Colors.white60 : Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      if (!notification.isRead)
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(shape: BoxShape.circle, color: notification.color),
                        ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(notification.body, style: const TextStyle(color: Colors.white38, fontSize: 12), maxLines: 2, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Text(_timeAgo(notification.timestamp), style: const TextStyle(color: Colors.white24, fontSize: 11)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

