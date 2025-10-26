import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_app/views/pages/login_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot){
        if (snapshot.connectionState == ConnectionState.waiting)
        {
          return const Scaffold(
             body: Center(
              child: CircularProgressIndicator(),
             ),
          );
        }
        final session = snapshot.hasData ? snapshot.data!.session : null;

        if (session != null) {
          // When signed in, navigate to the app shell. Use a post-frame callback
          // to avoid calling navigation during build.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            final current = GoRouterState.of(context).uri.path;
            if (current != '/app/home') {
              context.go('/app/home');
            }
          });
          return const SizedBox.shrink();
        } else {
          return LoginPage();
        }
      }
    );
  }
}