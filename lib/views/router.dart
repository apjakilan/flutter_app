import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_app/views/pages/welcome_page.dart';
import 'package:flutter_app/views/pages/login_page.dart';
import 'package:flutter_app/views/pages/registration_page.dart';
import 'package:flutter_app/views/pages/forgot_password_page.dart';
import 'package:flutter_app/views/pages/guest_profile_page.dart';
import 'package:flutter_app/views/pages/edit_profile_page.dart';
import 'package:flutter_app/views/pages/unified_search_page.dart';
import 'package:flutter_app/views/post_card.dart';
import 'package:flutter_app/views/widget_tree.dart';
import 'package:flutter_app/views/pages/home_page.dart';
import 'package:flutter_app/views/pages/discover_page.dart';
import 'package:flutter_app/views/pages/map_page.dart';
import 'package:flutter_app/views/pages/profile_page.dart';
import 'package:flutter_app/views/pages/post_detail_page.dart'; // 🚀 NEW IMPORT
import 'package:supabase_flutter/supabase_flutter.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

class _SupabaseAuthNotifier extends ChangeNotifier {
    _SupabaseAuthNotifier() {
        Supabase.instance.client.auth.onAuthStateChange.listen((_) => notifyListeners());
    }
}

final router = GoRouter(
    navigatorKey: _rootNavigatorKey,
    // Refresh when Supabase auth state changes so redirect runs automatically
    refreshListenable: _SupabaseAuthNotifier(),
    redirect: (context, state) {
        final loggedIn = Supabase.instance.client.auth.currentUser != null;
        final authPaths = {'/login', '/register', '/forgot-password', '/'};

        final location = state.uri.path;

        if (!loggedIn && !authPaths.contains(location)) {
            return '/login';
        }

        if (loggedIn && authPaths.contains(location)) {
            return '/app';
        }

        return null;
    },
    routes: [
        GoRoute(
            path: '/',
            builder: (context, state) => const WelcomePage(),
        ),
        GoRoute(
            path: '/login',
            builder: (context, state) => const LoginPage(),
        ),
        GoRoute(
            path: '/register',
            builder: (context, state) => const RegistrationPage(),
        ),
        GoRoute(
            path: '/forgot-password',
            builder: (context, state) => const ForgotPasswordPage(),
        ),
        // 🚀 NEW ROUTE: Post Detail Page
        GoRoute(
            path: '/post_detail/:postId', // Takes the post ID as a parameter
            builder: (context, state) {
                final postId = state.pathParameters['postId']!;
                return PostDetailPage(postId: postId);
            },
        ),
        GoRoute(
            path: '/search',
            builder: (context, state) => const UnifiedSearchPage(),
        ),
        GoRoute(
            path: '/post',
            builder: (context, state) => PostCard(),
        ),
        GoRoute(
            path: '/guest/:id',
            builder: (context, state) {
                final id = state.pathParameters['id'] ?? '';
                return GuestProfilePage(userId: id);
            },
        ),
        GoRoute(
            path: '/edit-profile',
            builder: (context, state) => const EditProfilePage(),
        ),
        // ShellRoute for the main app shell (bottom navigation) with nested routes
        ShellRoute(
            builder: (context, state, child) => AppShell(child: child),
            routes: [
                GoRoute(
                    path: '/app',
                    redirect: (context, state) => '/app/home',
                ),
                GoRoute(
                    path: '/app/home',
                    builder: (context, state) => const HomePage(),
                ),
                GoRoute(
                    path: '/app/profile',
                    builder: (context, state) => const ProfilePage(),
                ),
                GoRoute(
                    path: '/app/discover',
                    builder: (context, state) => const DiscoverPage(),
                ),
                GoRoute(
                    path: '/app/map',
                    builder: (context, state) => const MapPage(),
                ),
            ],
        ),
    ],
);