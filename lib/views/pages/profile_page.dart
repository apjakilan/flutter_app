import 'package:flutter/material.dart';
import 'package:flutter_app/views/pages/edit_profile_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Import the new shared post list widget (assuming you create one)
// For now, we'll keep the logic in the main page.

// Extend DefaultTabController to manage the tabs
class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

// Add SingleTickerProviderStateMixin for the TabController
class _ProfilePageState extends State<ProfilePage> with SingleTickerProviderStateMixin {
  final supabase = Supabase.instance.client;
  final title = 'Profile Page';

  String? avatarUrl;
  String? username;
  String? bio;
  bool isLoading = true;

  Future<List<Map<String, dynamic>>>? _userPostsFuture;
  Future<List<Map<String, dynamic>>>? _likedPostsFuture; // 💡 NEW: Future for liked posts
  String? currentUserId;

  late TabController _tabController; // 💡 NEW: Tab controller

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this); // Initialize with 2 tabs
    _loadProfileAndPosts();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // Combines loading the profile and refreshing both post types
  Future<void> _loadProfileAndPosts() async {
    if (!mounted) return;
    
    await _loadProfile();
    
    if (mounted) {
      setState(() {
        _userPostsFuture = _fetchUserPosts();
        _likedPostsFuture = _fetchLikedPosts(); // 💡 NEW: Refresh liked posts
      });
    }
  }

  // --- Profile Loading (No Change) ---
  Future<void> _loadProfile() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;
      
      currentUserId = user.id;

      final response = await supabase
          .from('profile')
          .select('avatar_url, username, bio')
          .eq('id', user.id)
          .maybeSingle();

      if (!mounted) return;

      setState(() {
        avatarUrl = response?['avatar_url'];
        username = response?['username'] ?? 'Unknown User';
        bio = response?['bio'] ?? '';
        isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading profile: $e');
      if (!mounted) return;
      setState(() {
        isLoading = false;
      });
    }
  }

  // --- Posts Loading (No Change) ---
  Future<List<Map<String, dynamic>>> _fetchUserPosts() async {
    final userId = currentUserId ?? supabase.auth.currentUser?.id;
    if (userId == null) return [];

    try {
      final posts = await supabase
          .from('posts')
          .select('*')
          .eq('user_id', userId)
          .order('created_at', ascending: false);
      
      if (!mounted) return []; 

      return List<Map<String, dynamic>>.from(posts);
    } catch (e) {
      debugPrint('Error fetching user posts: $e');
      return Future.error('Failed to load posts');
    }
  }

  // --- 💡 NEW: Liked Posts Loading ---
  Future<List<Map<String, dynamic>>> _fetchLikedPosts() async {
    final userId = currentUserId ?? supabase.auth.currentUser?.id;
    if (userId == null) return [];

    try {
      // 1. Select the post IDs from the 'likes' table that belong to the current user
      // 2. Join it with the 'posts' table to get the full post data
      final likedPosts = await supabase
          .from('likes')
          .select('posts!inner(*)') // 💡 IMPORTANT: Join on posts table
          .eq('user_id', userId)
          .order('created_at', ascending: false);
      
      if (!mounted) return [];

      // The result is an array of maps like: [{posts: {...post_data...}}, ...]
      // We need to extract the actual post data from the nested 'posts' key.
      return likedPosts.map<Map<String, dynamic>>((likeEntry) {
        return likeEntry['posts'] as Map<String, dynamic>;
      }).toList();

    } catch (e) {
      debugPrint('Error fetching liked posts: $e');
      return Future.error('Failed to load liked posts');
    }
  }

  Future<void> _logout() async {
    await supabase.auth.signOut();
  }

  // --- Widget for a Single Post Card (No Change) ---
  Widget _buildPostCard(Map<String, dynamic> post) {
    final content = post['content'] ?? '';
    final imageUrl = post['image_url'] as String?;
    final createdAt = post['created_at'] ?? '';

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 16, left: 16, right: 16),
            child: Text(
              content,
              style: const TextStyle(fontSize: 16),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 4, left: 16, right: 16, bottom: 8),
            child: Text(
              createdAt != ''
                  ? DateTime.parse(createdAt)
                      .toLocal()
                      .toString()
                      .substring(0, 16)
                  : 'Just now',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
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
                  return const SizedBox(
                    height: 200,
                    child: Center(child: CircularProgressIndicator()),
                  );
                },
                errorBuilder: (context, error, stackTrace) {
                  return const SizedBox(
                    height: 100,
                    child: Center(
                      child: Text('Image failed to load 😔', style: TextStyle(color: Colors.red)),
                    ),
                  );
                },
              ),
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  // --- 💡 NEW: Widget to display the Future list of posts (replaces old FutureBuilder) ---
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
          // Important: Prevents a nested scrollable error
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
      appBar: AppBar(title: Text(username ?? title), backgroundColor: Colors.teal),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadProfileAndPosts,
              child: Column(
                children: [
                  // --- 1. PROFILE HEADER SECTION (Moved to Column) ---
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Avatar & Username/Bio... (same as before)
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
                          username ?? 'Loading...',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          bio ?? 'No bio yet.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                        const SizedBox(height: 24),

                        // Edit Button
                        ElevatedButton.icon(
                          onPressed: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const EditProfilePage(),
                              ),
                            );
                            await _loadProfileAndPosts(); 
                          },
                          icon: const Icon(Icons.edit),
                          label: const Text('Edit Profile'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.teal.shade300,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
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
                      Tab(icon: Icon(Icons.favorite), text: 'Likes'),
                    ],
                  ),
                  
                  // --- 3. TAB BAR VIEW (Main content) ---
                  Expanded( // Use Expanded to give TabBarView the remaining height
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        // Posts Tab
                        SingleChildScrollView( // Keep SingleChildScrollView for pull-to-refresh to work
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16.0),
                            child: _buildPostList(_userPostsFuture, 'You haven\'t posted anything yet.'),
                          ),
                        ),

                        // Liked Posts Tab 💡 NEW
                        SingleChildScrollView(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16.0),
                            child: _buildPostList(_likedPostsFuture, 'You haven\'t liked any posts yet.'),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // Logout option (moved outside of the scrollable area if you want it sticky)
                  ListTile(
                    leading: const Icon(Icons.logout),
                    title: const Text('Logout'),
                    onTap: _logout,
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }
}