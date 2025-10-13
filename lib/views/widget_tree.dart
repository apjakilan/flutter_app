import 'package:flutter/material.dart';
import 'package:flutter_app/data/notifiers.dart';
import 'package:flutter_app/views/pages/home_page.dart';
import 'package:flutter_app/views/pages/login_page.dart';
import 'package:flutter_app/views/pages/map_page.dart';
import 'package:flutter_app/views/pages/post_page.dart';
import 'package:flutter_app/views/pages/profile_page.dart';
import 'package:flutter_app/views/pages/registration_page.dart';
import 'package:flutter_app/views/widgets/navbar_widget.dart';

List<Widget> pages = [HomePage(), ProfilePage(), PostPage(), MapPage()];

class WidgetTree extends StatelessWidget {
  const WidgetTree({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Snap2Store'),
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
      drawer: Drawer(
        child: Column(
          children: [
            ListTile(leading: Icon(Icons.home), title: Text("Home")),
            ListTile(leading: Icon(Icons.login_outlined), title: Text("Login Page"),onTap: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (context) => LoginPage()));
            }, ),
            ListTile(leading: Icon(Icons.app_registration_outlined), title: Text("Registration Page"),onTap: () {
              Navigator.pop(context); 
              Navigator.push(context, MaterialPageRoute(builder: (context) => RegistrationPage()));
              
            },),
            ListTile(leading: Icon(Icons.person), title: Text("Person Page")),

          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        child: Icon(Icons.add),
      ),
      body: ValueListenableBuilder(
        valueListenable: selectedPageNotifier,
        builder: (context, value, child) {
          return pages.elementAt(value);
        },
      ),
      bottomNavigationBar: NavbarWidget(),
    );
  }
}
