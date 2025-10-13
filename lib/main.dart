import 'package:flutter/material.dart';
import 'package:flutter_app/data/notifiers.dart';
import 'package:flutter_app/views/pages/login_page.dart';
import 'package:flutter_app/views/pages/registration_page.dart';
import 'package:flutter_app/views/pages/welcome_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';


Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://cfprqgciucpwwszdtrjg.supabase.co', 
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImNmcHJxZ2NpdWNwd3dzemR0cmpnIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjAyOTk1NDgsImV4cCI6MjA3NTg3NTU0OH0.q3_rJp41k2EifCRYYENUybANuXEsjI0tAxOzA-7x-qo');

  runApp(const MyApp());  
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: darkLightMode,
      builder: (context, isDarkMode, child) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.teal,
              brightness: isDarkMode ? Brightness.dark : Brightness.light,
            ),
          ),
          home: WelcomePage(),
          routes: {
            '/firstpage': (context) => RegistrationPage(),
            '/secondpage':(context) => LoginPage(),

          },
        );
      }
    );
  } 
}

