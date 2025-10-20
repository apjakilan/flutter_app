import 'package:flutter/material.dart';
import 'package:flutter_app/views/pages/edit_profile_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final supabase = Supabase.instance.client;
  final title = 'Profile Page';

  String? avatarUrl;
  String? username;
  String? bio;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

Future<void> _loadProfile() async {
  try {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    final response = await supabase
        .from('profile')
        .select('avatar_url, username, bio')
        .eq('id', user.id)
        .maybeSingle();

    if (!mounted) return; // ✅ Prevent setState on disposed widget

    setState(() {
      avatarUrl = response?['avatar_url'];
      username = response?['username'] ?? 'Unknown User';
      bio = response?['bio'] ?? '';
      isLoading = false;
    });
  } catch (e) {
    debugPrint('Error loading profile: $e');
    if (!mounted) return; // ✅ Add safety here too
    setState(() {
      isLoading = false;
    });
  }
}

  Future<void> _logout() async {
    await supabase.auth.signOut();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title), backgroundColor: Colors.teal),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadProfile,
              child: ListView(
                padding: const EdgeInsets.all(16.0),
                children: [
                  // ✅ Avatar with Supabase image
                  CircleAvatar(
                    radius: 60,
                    backgroundImage: (avatarUrl != null && avatarUrl!.isNotEmpty)
                        ? NetworkImage(avatarUrl!)
                        : null,
                    child: (avatarUrl == null || avatarUrl!.isEmpty)
                        ? const Icon(Icons.person, size: 60)
                        : null,
                  ),
                  const SizedBox(height: 16),

                  // ✅ Username
                  Text(
                    username ?? 'Loading...',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 8),

                  // ✅ Bio or subtitle
                  Text(
                    bio ?? '',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 16, color: Colors.grey),
                  ),

                  const SizedBox(height: 24),

                  // ✅ Edit button that refreshes profile after returning
                  ElevatedButton(
                    onPressed: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const EditProfilePage(),
                        ),
                      );

                      // 🔄 Refresh avatar after returning from edit page
                      await _loadProfile();
                    },
                    child: const Text('Edit Profile'),
                  ),

                  const Divider(height: 40),

                  // ✅ Logout option
                  ListTile(
                    leading: const Icon(Icons.logout),
                    title: const Text('Logout'),
                    onTap: _logout,
                  ),
                ],
              ),
            ),
    );
  }
}
