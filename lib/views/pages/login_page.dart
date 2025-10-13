import 'package:flutter/material.dart';
import 'package:flutter_app/data/notifiers.dart';

class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Login Page'),
        actions: [
          IconButton(
            onPressed: () {
              darkLightMode.value = !darkLightMode.value;
            },
            icon: ValueListenableBuilder(
              valueListenable: darkLightMode,
              builder: (context, isDarkMode, child) {
                return Icon(isDarkMode ? Icons.dark_mode : Icons.light_mode);
              },
            ),
          ),
        ],
        centerTitle: true,
        backgroundColor: Colors.teal,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextField(
                decoration: InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: "Username",
                  hintStyle: TextStyle(color: Colors.grey),
                ),
              ),
              SizedBox(
                height: 8,
              ),
              TextField(
                decoration: InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: "Password",
                  hintStyle: TextStyle(color: Colors.grey),
                ),
              ),
              Row(
                children: [
                  ElevatedButton(onPressed: () {
                    
                  }, child: Text("Enter")),
                  ElevatedButton(onPressed: () {
                    
                  }, child: Text("Forgot Password")),
                ],
              )            
            ],
          ),
        ),
      ),
    );
  }
}
