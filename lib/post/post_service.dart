import 'dart:io' show File;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

Future<String?> uploadProfilePicture(BuildContext context) async {
  final supabase = Supabase.instance.client;
  final user = supabase.auth.currentUser;
  if (user == null) return null;

  final ImagePicker picker = ImagePicker();
  final XFile? pickedFile = await picker.pickImage(source: ImageSource.gallery);
  if (pickedFile == null) return null;

  final filePath = 'avatars/${user.id}/${DateTime.now().millisecondsSinceEpoch}.jpg';
  final bucket = supabase.storage.from('avatars');

  try {
    if (kIsWeb) {
      final bytes = await pickedFile.readAsBytes();
      await bucket.uploadBinary(filePath, bytes, fileOptions: const FileOptions(upsert: true));
    } else {
      final file = File(pickedFile.path);
      await bucket.upload(filePath, file, fileOptions: const FileOptions(upsert: true));
    }

    // Get the public URL
    final publicUrl = bucket.getPublicUrl(filePath);

    // Update Supabase profile table
    await supabase.from('profile').update({'avatar_url': publicUrl}).eq('id', user.id);

    print('✅ Image uploaded successfully!');
    return publicUrl;
  } catch (e) {
    print('❌ Error uploading image: $e');
    return null;
  }
}



class PostService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // Fetch posts from 'posts' table
Future<List<Map<String, dynamic>>> fetchAllPosts() async {
  // Select posts and join with profiles to get the username and avatar
  final List<Map<String, dynamic>> data = await _supabase
      .from('posts')
      .select('*, profile(username, avatar_url)')
      .order('created_at', ascending: false);
      
  return data;
}



}