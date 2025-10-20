import 'package:flutter/material.dart';
import 'package:flutter_app/auth/auth_service.dart';
import 'package:flutter_app/data/notifiers.dart';
import 'package:flutter_app/views/pages/home_page.dart';
import 'package:flutter_app/views/pages/login_page.dart';
import 'package:flutter_app/views/pages/map_page.dart';
import 'package:flutter_app/views/pages/discover_page.dart';
import 'package:flutter_app/views/pages/profile_page.dart';
import 'package:flutter_app/views/pages/registration_page.dart';
import 'package:flutter_app/views/post_card.dart';
import 'package:flutter_app/views/widgets/navbar_widget.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

List<Widget> pages = [HomePage(), ProfilePage(), DiscoverPage(), MapPage()];

class WidgetTree extends StatefulWidget {
  const WidgetTree({super.key});

  @override
  State<WidgetTree> createState() => _WidgetTreeState();
}

class _WidgetTreeState extends State<WidgetTree> {
  final authService = AuthService();

  void logOut() async {
    await authService.signOut();
  }

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
          IconButton(onPressed: logOut, icon: Icon(Icons.logout)),
        ],
        centerTitle: true,
        backgroundColor: Colors.teal,
      ),
      drawer: Drawer(
        child: Column(
          children: [
            ListTile(leading: Icon(Icons.home), title: Text("Home")),
            ListTile(
              leading: Icon(Icons.login_outlined),
              title: Text("Login Page"),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => LoginPage()),
                );
              },
            ),
            ListTile(
              leading: Icon(Icons.app_registration_outlined),
              title: Text("Registration Page"),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => RegistrationPage()),
                );
              },
            ),
            ListTile(
              leading: Icon(Icons.person),
              title: Text("Post Card"),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => PostCard()),
                );
              },
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          showDialog(
            context: context,
            builder: (context) {
              final supabase = Supabase.instance.client;
              final user = supabase.auth.currentUser;
              final controller = TextEditingController();

              return SimpleDialog(
                title: const Text('Create a Post'),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 20,
                ),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: TextField(
                      controller: controller,
                      autofocus: true,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        hintText: 'What’s on your mind?',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.send),
                    label: const Text('Post'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                    ),
                    onPressed: () async {
                      final content = controller.text.trim();
                      if (content.isEmpty) return;

                      if (user == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('You must be logged in to post.'),
                          ),
                        );
                        return;
                      }

                      try {
                        // ✅ Insert new post into Supabase
                        await supabase.from('posts').insert({
                          'user_id': user.id,
                          'content': content,
                        });

                        if (context.mounted) {
                          Navigator.pop(context); // Close dialog
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Post created successfully!'),
                            ),
                          );
                        }
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error creating post: $e')),
                        );
                      }
                    },
                  ),
                ],
              );
            },
          );
        },
        backgroundColor: Colors.teal,
        child: const Icon(Icons.add),
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
