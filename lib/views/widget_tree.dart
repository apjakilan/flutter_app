// Removed dart:io import — prefer using Uint8List for cross-platform image handling
import 'dart:typed_data'; // Required for Uint8List
import 'package:flutter/material.dart';
import 'package:flutter_app/auth/auth_service.dart';
import 'package:flutter_app/data/notifiers.dart';
import 'package:flutter_app/views/pages/home_page.dart';
import 'package:flutter_app/views/pages/map_page.dart';
import 'package:flutter_app/views/pages/discover_page.dart';
import 'package:flutter_app/views/pages/profile_page.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_app/views/widgets/navbar_widget.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart'; // Required for image selection

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
  Uint8List? _imageBytes;
  String? _imageFileName;
  final _picker = ImagePicker();

  void logOut() async {
    await authService.signOut();
  }

  Future<String?> _uploadImageToSupabase(Uint8List imageBytes, String fileName) async {
    try {
      final supabase = Supabase.instance.client;
      final userId = supabase.auth.currentUser!.id;

      final finalFileName = fileName.isNotEmpty
          ? '${userId}_${DateTime.now().millisecondsSinceEpoch}_$fileName'
          : '${userId}_${DateTime.now().millisecondsSinceEpoch}.jpg';

      final storagePath = 'public/$finalFileName';

      await supabase.storage
          .from('post_images')
          .uploadBinary(storagePath, imageBytes, fileOptions: const FileOptions(cacheControl: '3600', contentType: 'image/jpeg'));

      final publicUrl = supabase.storage.from('post_images').getPublicUrl(storagePath);
      return publicUrl;
    } catch (e) {
      debugPrint('Error uploading image to Supabase: $e');
      return null;
    }
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
          ),
          IconButton(
            onPressed: () => darkLightMode.value = !darkLightMode.value,
            icon: ValueListenableBuilder(
              valueListenable: darkLightMode,
              builder: (context, isDarkMode, child) => Icon(isDarkMode ? Icons.dark_mode : Icons.light_mode),
            ),
          ),
          IconButton(onPressed: logOut, icon: const Icon(Icons.logout)),
        ],
        centerTitle: true,
        backgroundColor: Colors.teal,
      ),
      drawer: Drawer(
        child: Column(
          children: [
            const ListTile(leading: Icon(Icons.home), title: Text("Home")),
            ListTile(
              leading: const Icon(Icons.login_outlined),
              title: const Text("Login Page"),
              onTap: () {
                Navigator.pop(context);
                context.push('/login');
              },
            ),
            ListTile(
              leading: const Icon(Icons.app_registration_outlined),
              title: const Text("Registration Page"),
              onTap: () {
                Navigator.pop(context);
                context.push('/register');
              },
            ),
            ListTile(
              leading: const Icon(Icons.person),
              title: const Text("Post Card"),
              onTap: () {
                Navigator.pop(context);
                context.push('/post');
              },
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _imageBytes = null;
          _imageFileName = null;

          showDialog(
            context: context,
            builder: (context) {
              final supabase = Supabase.instance.client;
              final user = supabase.auth.currentUser;
              final controller = TextEditingController();

              return StatefulBuilder(
                builder: (context, setStateInDialog) {
                  void selectImage() async {
                    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
                    if (pickedFile != null) {
                      final bytes = await pickedFile.readAsBytes();
                      setStateInDialog(() {
                        _imageBytes = bytes;
                        _imageFileName = pickedFile.name;
                      });
                    }
                  }

                  Future<void> createPost() async {
                    final content = controller.text.trim();
                    if (content.isEmpty && _imageBytes == null) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter text or select an image to post.')));
                      }
                      return;
                    }

                    if (user == null) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('You must be logged in to post.')));
                      }
                      return;
                    }

                    String? imageUrl;
                    if (_imageBytes != null && _imageFileName != null) {
                      imageUrl = await _uploadImageToSupabase(_imageBytes!, _imageFileName!);
                      if (imageUrl == null) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to upload image. Post aborted.')));
                          return;
                        }
                      }
                    }

                    try {
                      await supabase.from('posts').insert({'user_id': user.id, 'content': content, 'image_url': imageUrl});
                      if (context.mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Post created successfully!')));
                      }
                    } catch (e) {
                      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error creating post: $e')));
                    }
                  }

                  return SimpleDialog(
                    title: const Text('Create a Post'),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                    children: [
                      if (_imageBytes != null) Padding(padding: const EdgeInsets.only(bottom: 10), child: Image.memory(_imageBytes!, height: 150, fit: BoxFit.cover)),
                      Padding(padding: const EdgeInsets.all(8.0), child: TextField(controller: controller, autofocus: true, maxLines: 4, decoration: const InputDecoration(hintText: 'What’s on your mind?', border: OutlineInputBorder()))),
                      const SizedBox(height: 10),
                      TextButton.icon(icon: const Icon(Icons.image), label: Text(_imageBytes == null ? 'Add Image' : 'Change Image'), onPressed: selectImage),
                      const SizedBox(height: 10),
                      ElevatedButton.icon(icon: const Icon(Icons.send), label: const Text('Post'), style: ElevatedButton.styleFrom(backgroundColor: Colors.teal), onPressed: createPost),
                    ],
                  );
                },
              );
            },
          );
        },
        backgroundColor: Colors.teal,
        child: const Icon(Icons.add),
      ),
      body: widget.child,
      bottomNavigationBar: const NavbarWidget(),
    );
  }
}
