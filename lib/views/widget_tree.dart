import 'dart:io'
    show
        File; // Only import File for type compatibility, but we primarily use Uint8List
import 'dart:typed_data'; // Required for Uint8List
import 'package:flutter/material.dart';
import 'package:flutter_app/auth/auth_service.dart';
import 'package:flutter_app/data/notifiers.dart';
import 'package:flutter_app/views/pages/home_page.dart';
import 'package:flutter_app/views/pages/login_page.dart';
import 'package:flutter_app/views/pages/map_page.dart';
import 'package:flutter_app/views/pages/discover_page.dart';
import 'package:flutter_app/views/pages/profile_page.dart';
import 'package:flutter_app/views/pages/registration_page.dart';
import 'package:flutter_app/views/pages/unified_search_page.dart';
import 'package:flutter_app/views/post_card.dart';
import 'package:flutter_app/views/widgets/navbar_widget.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart'; // Required for image selection

List<Widget> pages = [HomePage(), ProfilePage(), DiscoverPage(), MapPage()];

class WidgetTree extends StatefulWidget {
  const WidgetTree({super.key});

  @override
  State<WidgetTree> createState() => _WidgetTreeState();
}

class _WidgetTreeState extends State<WidgetTree> {
  final authService = AuthService();

  // === CROSS-PLATFORM IMAGE POSTING STATE & FUNCTIONS ===
  Uint8List? _imageBytes; // Stores image data as bytes (cross-platform)
  String?
  _imageFileName; // Stores the file name from image_picker (useful for upload)
  final _picker = ImagePicker();

  void logOut() async {
    await authService.signOut();
  }

  // Supabase Upload Function - now accepts Uint8List
  // NOTE: Requires a 'post_images' bucket and policies to be set in Supabase.
  Future<String?> _uploadImageToSupabase(
    Uint8List imageBytes,
    String fileName,
  ) async {
    try {
      final supabase = Supabase.instance.client;
      final userId = supabase.auth.currentUser!.id;

      // Use the provided fileName or generate a unique one if not available
      final finalFileName = fileName.isNotEmpty
          ? '${userId}_${DateTime.now().millisecondsSinceEpoch}_$fileName'
          : '${userId}_${DateTime.now().millisecondsSinceEpoch}.jpg';

      final storagePath = 'public/$finalFileName';

      // 1. Upload the byte data to Supabase Storage using uploadBinary
      await supabase.storage
          .from('post_images')
          .uploadBinary(
            storagePath,
            imageBytes,
            fileOptions: const FileOptions(
              cacheControl: '3600',
              contentType:
                  'image/jpeg', // Assuming JPEG, adjust if you handle other formats
            ),
          );

      // 2. Get the publicly accessible URL
      final publicUrl = supabase.storage
          .from('post_images')
          .getPublicUrl(storagePath);

      return publicUrl;
    } catch (e) {
      print('Error uploading image to Supabase: $e');
      return null;
    }
  }
  // ===========================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Snap2Store'),
        actions: [
          IconButton(
            onPressed: () {
              // 💡 IMPLEMENT NAVIGATION HERE
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const UnifiedSearchPage(), // NAVIGATE
                ),
              );
            },
            icon: Icon(Icons.search),
          ),
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
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => LoginPage()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.app_registration_outlined),
              title: const Text("Registration Page"),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => RegistrationPage()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.person),
              title: const Text("Post Card"),
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
          // Reset the image state before showing the dialog
          _imageBytes = null;
          _imageFileName = null;

          showDialog(
            context: context,
            builder: (context) {
              final supabase = Supabase.instance.client;
              final user = supabase.auth.currentUser;
              final controller = TextEditingController();

              // Use a StatefulBuilder to manage the image selection state within the dialog
              return StatefulBuilder(
                builder: (context, setStateInDialog) {
                  // Function to pick image and update dialog state
                  void selectImage() async {
                    final pickedFile = await _picker.pickImage(
                      source: ImageSource.gallery,
                    );

                    if (pickedFile != null) {
                      final bytes = await pickedFile
                          .readAsBytes(); // Read data as bytes (cross-platform)
                      setStateInDialog(() {
                        _imageBytes = bytes;
                        _imageFileName =
                            pickedFile.name; // Store original file name
                      });
                    }
                  }

                  // Function to handle posting logic
                  Future<void> createPost() async {
                    final content = controller.text.trim();

                    // Prevent posting if both text and image are empty
                    if (content.isEmpty && _imageBytes == null) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Please enter text or select an image to post.',
                            ),
                          ),
                        );
                      }
                      return;
                    }

                    if (user == null) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('You must be logged in to post.'),
                          ),
                        );
                      }
                      return;
                    }

                    // Variable to hold the URL of the uploaded image
                    String? imageUrl;

                    // 1. UPLOAD IMAGE if one is selected
                    if (_imageBytes != null && _imageFileName != null) {
                      imageUrl = await _uploadImageToSupabase(
                        _imageBytes!,
                        _imageFileName!,
                      );
                      if (imageUrl == null) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Failed to upload image. Post aborted.',
                              ),
                            ),
                          );
                          return; // Stop execution if image upload fails
                        }
                      }
                    }

                    try {
                      // 2. INSERT post data (including image URL) into Supabase
                      await supabase.from('posts').insert({
                        'user_id': user.id,
                        'content': content,
                        'image_url':
                            imageUrl, // This will be null if no image was selected
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
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error creating post: $e')),
                        );
                      }
                    }
                  }

                  return SimpleDialog(
                    title: const Text('Create a Post'),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 20,
                    ),
                    children: [
                      // Image Preview - uses Image.memory for cross-platform support
                      if (_imageBytes != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Image.memory(
                            _imageBytes!, // Display from bytes
                            height: 150,
                            fit: BoxFit.cover,
                          ),
                        ),

                      // Text Field
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

                      // Image Picker Button
                      TextButton.icon(
                        icon: const Icon(Icons.image),
                        label: Text(
                          _imageBytes == null ? 'Add Image' : 'Change Image',
                        ),
                        onPressed: selectImage,
                      ),

                      const SizedBox(height: 10),

                      // Post Button
                      ElevatedButton.icon(
                        icon: const Icon(Icons.send),
                        label: const Text('Post'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal,
                        ),
                        onPressed: createPost, // Calls the combined logic
                      ),
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
