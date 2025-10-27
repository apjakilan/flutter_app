// Removed dart:io import — prefer using Uint8List for cross-platform image handling
// imports kept minimal for the shell
import 'package:flutter/material.dart';
import 'package:flutter_app/auth/auth_service.dart';
import 'package:flutter_app/data/notifiers.dart';
import 'package:flutter_app/views/pages/home_page.dart';
import 'package:flutter_app/views/pages/map_page.dart';
import 'package:flutter_app/views/pages/discover_page.dart';
import 'package:flutter_app/views/pages/profile_page.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_app/views/widgets/navbar_widget.dart';
// supabase and image picker are not used in the shell; pages own post creation

// Keep the original pages list for backward compatibility if needed elsewhere
List<Widget> pages = [HomePage(), ProfilePage(), DiscoverPage(), MapPage()];

/// AppShell is the Scaffold used as a ShellRoute builder. It renders the
/// AppBar, Drawer, FloatingActionButton and a bottom navigation bar and
/// places the current nested route's child into the body.
class AppShell extends StatefulWidget {
  final Widget child;
  const AppShell({super.key, required this.child});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  final authService = AuthService();
  void logOut() async {
    await authService.signOut();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Snap2Store'),
        actions: [
          IconButton(
            onPressed: () => context.push('/search'),
            icon: const Icon(Icons.search),
            tooltip: 'Search',
          ),
          IconButton(
            onPressed: () => darkLightMode.value = !darkLightMode.value,
            icon: ValueListenableBuilder(
              valueListenable: darkLightMode,
              builder: (context, isDarkMode, child) => Icon(isDarkMode ? Icons.dark_mode : Icons.light_mode),
            ),
            tooltip: 'Toggle theme',
          ),
          IconButton(onPressed: logOut, icon: const Icon(Icons.logout), tooltip: 'Logout'),
        ],
        centerTitle: true,
        backgroundColor: Colors.teal,
      ),
      // Drawer removed: it was only used for testing navigation shortcuts.
      // FAB is intentionally removed from the shell so pages can opt-in
      // by placing their own `CreatePostFab` when appropriate (Home, Profile).
      body: widget.child,
      bottomNavigationBar: const NavbarWidget(),
    );
  }
}
