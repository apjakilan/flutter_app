import 'package:flutter/material.dart';
import 'package:flutter_app/auth/auth_gate.dart';
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
              child: Image.asset('assets/images/thestrokes.jpeg'),
            ),
            FilledButton(onPressed: () {
              Navigator.pushReplacement(
                context, 
                MaterialPageRoute(builder: (context) {
                  return AuthGate();
                }));
            }, child: Text("Login"))
          ],
        ),
      ), 
    );
  }
}