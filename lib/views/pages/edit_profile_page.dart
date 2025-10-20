import 'dart:io' show File;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_app/post/post_service.dart';

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final supabase = Supabase.instance.client;
  final _usernameController = TextEditingController();
  final _bioController = TextEditingController();

  File? _profileImage;
  String? _profileImageUrl;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentProfile();
  }

  Future<void> _loadCurrentProfile() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    final response = await supabase
        .from('profile')
        .select('username, bio, avatar_url')
        .eq('id', user.id)
        .maybeSingle();

    if (response != null) {
      setState(() {
        _usernameController.text = response['username'] ?? '';
        _bioController.text = response['bio'] ?? '';
        _profileImageUrl = response['avatar_url'];
      });
    }
  }

  Future<void> _saveProfileChanges() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    setState(() => _isSaving = true);

    try {
      await supabase.from('profile').update({
        'username': _usernameController.text.trim(),
        'bio': _bioController.text.trim(),
        if (_profileImageUrl != null) 'avatar_url': _profileImageUrl,
      }).eq('id', user.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Profile updated successfully!')),
        );
        Navigator.pop(context); // Go back to ProfilePage
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Error updating profile: $e')),
      );
    } finally {
      setState(() => _isSaving = false);
    }
  }

  Future<void> _pickNewAvatar() async {
    final imageUrl = await uploadProfilePicture(context);
    if (imageUrl != null) {
      setState(() {
        _profileImageUrl = imageUrl;
        _profileImage = kIsWeb ? null : File(imageUrl);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('🖼️ Profile picture updated!')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile'),
        backgroundColor: Colors.teal,
      ),
      body: _isSaving
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16.0),
              children: [
                // Avatar
                GestureDetector(
                  onTap: _pickNewAvatar,
                  child: CircleAvatar(
                    radius: 60,
                    backgroundImage: _profileImage != null
                        ? FileImage(_profileImage!)
                        : (_profileImageUrl != null
                            ? NetworkImage(_profileImageUrl!)
                            : null),
                    child: _profileImage == null && _profileImageUrl == null
                        ? Icon(Icons.camera_alt,
                            size: 50, color: Colors.grey[700])
                        : null,
                  ),
                ),
                const SizedBox(height: 24),

                TextField(
                  controller: _usernameController,
                  decoration: const InputDecoration(
                    labelText: 'Username',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),

                TextField(
                  controller: _bioController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Bio',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 24),

                ElevatedButton(
                  onPressed: _isSaving ? null : _saveProfileChanges,
                  child: const Text('Save Changes'),
                ),
              ],
            ),
    );
  }
}
