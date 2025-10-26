import 'package:flutter/material.dart';
// auth_gate is not needed here when using go_router
import 'package:go_router/go_router.dart';
//import 'package:flutter_app/views/widget_tree.dart';

class WelcomePage extends StatelessWidget {
  const WelcomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          spacing: 10,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ClipRRect(
              borderRadius: BorderRadiusGeometry.circular(20),
              child: Image.asset('/images/thestrokes.jpeg'),
            ),
            FilledButton(onPressed: () {
              // Use go_router to navigate to the login route
              context.go('/login');
            }, child: const Text("Login"))
          ],
        ),
      ), 
    );
  }
}