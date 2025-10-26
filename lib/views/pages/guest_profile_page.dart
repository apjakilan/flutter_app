import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class GuestProfilePage extends StatefulWidget {
  final String userId;

  const GuestProfilePage({super.key, required this.userId});

  @override
  State<GuestProfilePage> createState() => _GuestProfilePageState();
}

// Add SingleTickerProviderStateMixin for the TabController
class _GuestProfilePageState extends State<GuestProfilePage> with SingleTickerProviderStateMixin {
  final supabase = Supabase.instance.client;
  String? avatarUrl;
  String? username;
  String? bio;
  bool isLoading = true;

  Future<List<Map<String, dynamic>>>? _userPostsFuture;
  Future<List<Map<String, dynamic>>>? _likedPostsFuture; // 💡 NEW: Future for liked posts

  late TabController _tabController; // 💡 NEW: Tab controller

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this); // Initialize with 2 tabs
    _loadProfileAndPosts(widget.userId);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // --- Profile & Posts Loading ---
  Future<void> _loadProfileAndPosts(String userId) async {
    if (!mounted) return;
    
    await _loadProfile(userId);
    
    if (mounted) {
      setState(() {
        _userPostsFuture = _fetchUserPosts(userId);
        _likedPostsFuture = _fetchLikedPosts(userId); // 💡 NEW: Refresh liked posts
      });
    }
  }

  // --- Profile Loading (No Change) ---
  Future<void> _loadProfile(String userId) async {
    try {
      final response = await supabase
          .from('profile')
          .select('avatar_url, username, bio')
          .eq('id', userId)
          .maybeSingle();

      if (!mounted) return;

      setState(() {
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

  // --- Posts Loading (No Change) ---
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

  // --- 💡 NEW: Liked Posts Loading (Using the Guest userId) ---
  Future<List<Map<String, dynamic>>> _fetchLikedPosts(String userId) async {
    try {
      final likedPosts = await supabase
          .from('likes')
          .select('posts!inner(*)') // 💡 IMPORTANT: Join on posts table
          .eq('user_id', userId)
          .order('created_at', ascending: false);
      
      if (!mounted) return [];

      // Extract the actual post data from the nested 'posts' key.
      return likedPosts.map<Map<String, dynamic>>((likeEntry) {
        return likeEntry['posts'] as Map<String, dynamic>;
      }).toList();

    } catch (e) {
      debugPrint('Error fetching guest liked posts: $e');
      return Future.error('Failed to load liked posts');
    }
  }

  // --- Widget for a Single Post Card (No Change) ---
  Widget _buildPostCard(Map<String, dynamic> post) {
    // ... (Post Card implementation remains the same as in the original GuestProfilePage)
    final content = post['content'] ?? '';
    final imageUrl = post['image_url'] as String?;

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


  // --- 💡 NEW: Widget to display the Future list of posts ---
  Widget _buildPostList(Future<List<Map<String, dynamic>>>? future, String emptyMessage) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text('Error loading data: ${snapshot.error}'),
            ),
          );
        }

        final posts = snapshot.data ?? [];
        if (posts.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(emptyMessage),
            ),
          );
        }

        return ListView.builder(
          physics: const NeverScrollableScrollPhysics(), 
          shrinkWrap: true,
          itemCount: posts.length,
          itemBuilder: (context, index) {
            return _buildPostCard(posts[index]);
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(username ?? 'Loading Profile'), backgroundColor: Colors.teal),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () => _loadProfileAndPosts(widget.userId),
              child: Column( // Change ListView to Column to properly house the TabBar
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
                      ],
                    ),
                  ),

                  // --- 2. TAB BAR ---
                  TabBar(
                    controller: _tabController,
                    labelColor: Colors.teal,
                    unselectedLabelColor: Colors.grey,
                    indicatorColor: Colors.teal,
                    tabs: const [
                      Tab(icon: Icon(Icons.article), text: 'Posts'),
                      Tab(icon: Icon(Icons.favorite), text: 'Likes'), // 💡 NEW: Likes Tab
                    ],
                  ),
                  
                  // --- 3. TAB BAR VIEW (Main content) ---
                  Expanded( // Use Expanded to give TabBarView the remaining height
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        // Posts Tab
                        SingleChildScrollView(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16.0),
                            child: _buildPostList(_userPostsFuture, 'This user hasn\'t posted anything yet.'),
                          ),
                        ),

                        // Liked Posts Tab 💡 NEW
                        SingleChildScrollView(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16.0),
                            child: _buildPostList(_likedPostsFuture, 'This user hasn\'t liked any posts yet.'),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }
}