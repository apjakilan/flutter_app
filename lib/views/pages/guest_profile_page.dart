import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// The page now requires a userId in its constructor.
class GuestProfilePage extends StatefulWidget {
  final String userId;

  const GuestProfilePage({super.key, required this.userId});

  @override
  State<GuestProfilePage> createState() => _GuestProfilePageState();
}

class _GuestProfilePageState extends State<GuestProfilePage> {
  final supabase = Supabase.instance.client;
  String? avatarUrl;
  String? username;
  String? bio;
  bool isLoading = true;

  Future<List<Map<String, dynamic>>>? _userPostsFuture;

  @override
  void initState() {
    super.initState();
    // Load data for the user ID passed from the constructor
    _loadProfileAndPosts(widget.userId);
  }

  // --- Profile & Posts Loading ---
  Future<void> _loadProfileAndPosts(String userId) async {
    if (!mounted) return;
    
    await _loadProfile(userId);
    
    if (mounted) {
      setState(() {
        _userPostsFuture = _fetchUserPosts(userId);
      });
    }
  }

  // Uses the passed userId to fetch profile data
  Future<void> _loadProfile(String userId) async {
    try {
      final response = await supabase
          .from('profile')
          .select('avatar_url, username, bio')
          .eq('id', userId)
          .maybeSingle();

      if (!mounted) return;

      setState(() {
        // Use the fetched username for the AppBar title
        username = response?['username'] ?? 'User Profile';
        avatarUrl = response?['avatar_url'];
        bio = response?['bio'] ?? 'This user has not set a bio yet.';
        isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading guest profile: $e');
      if (!mounted) return;
      setState(() {
        isLoading = false;
      });
    }
  }

  // Uses the passed userId to fetch posts
  Future<List<Map<String, dynamic>>> _fetchUserPosts(String userId) async {
    try {
      final posts = await supabase
          .from('posts')
          .select('*')
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      if (!mounted) return []; 
      
      return List<Map<String, dynamic>>.from(posts);
    } catch (e) {
      debugPrint('Error fetching guest user posts: $e');
      return Future.error('Failed to load posts');
    }
  }

  // --- Widget for a Single Post Card (Same as in ProfilePage) ---
  Widget _buildPostCard(Map<String, dynamic> post) {
    final content = post['content'] ?? '';
    final imageUrl = post['image_url'] as String?;
    final createdAt = post['created_at'] ?? '';

    // Simplified Post Card for Guest View
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(content, style: const TextStyle(fontSize: 16)),
          ),
          if (imageUrl != null && imageUrl.isNotEmpty)
            ClipRRect(
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(10)),
              child: Image.network(
                imageUrl,
                fit: BoxFit.cover,
                width: double.infinity,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return const SizedBox(height: 200, child: Center(child: CircularProgressIndicator()));
                },
                errorBuilder: (context, error, stackTrace) {
                  return const SizedBox(height: 100, child: Center(child: Text('Image failed to load 😔')));
                },
              ),
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Title shows the user's username
      appBar: AppBar(title: Text(username ?? 'Loading Profile'), backgroundColor: Colors.teal),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () => _loadProfileAndPosts(widget.userId),
              child: ListView(
                children: [
                  // --- 1. PROFILE HEADER SECTION ---
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
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
                        Text(
                          username ?? 'User Profile',
                          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          bio ?? '',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                        
                        const Divider(height: 40),

                        const Text(
                          'Posts',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),

                  // --- 2. USER POSTS FEED SECTION ---
                  FutureBuilder<List<Map<String, dynamic>>>(
                    future: _userPostsFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      
                      final userPosts = snapshot.data ?? [];
                      if (userPosts.isEmpty) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(16.0),
                            child: Text('This user hasn\'t posted anything yet.'),
                          ),
                        );
                      }

                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: userPosts.map(_buildPostCard).toList(),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }
}