import 'package:flutter/material.dart';

class WelcomePage extends StatelessWidget {
  const WelcomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ClipRRect(
              child: Image.asset("assets/images/thestrokes.jpg"),
            ),
            FilledButton(onPressed: () {
              
            }, child: Text("Login"))
        
          ],
        ),
      ),
    );
  }
}