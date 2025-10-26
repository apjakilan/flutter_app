import 'package:flutter/material.dart';
import 'package:flutter_app/views/pages/edit_profile_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> with SingleTickerProviderStateMixin {
  final supabase = Supabase.instance.client;
  final title = 'Profile Page';

  String? avatarUrl;
  String? username;
  String? bio;
  bool isLoading = true;

  Future<List<Map<String, dynamic>>>? _userPostsFuture;
  Future<List<Map<String, dynamic>>>? _likedPostsFuture;
  String? currentUserId;

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadProfileAndPosts();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadProfileAndPosts() async {
    if (!mounted) return;
    await _loadProfile();
    if (mounted) {
      setState(() {
        _userPostsFuture = _fetchUserPosts();
        _likedPostsFuture = _fetchLikedPosts();
      });
    }
  }

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

  Future<List<Map<String, dynamic>>> _fetchLikedPosts() async {
    final userId = currentUserId ?? supabase.auth.currentUser?.id;
    if (userId == null) return [];

    try {
      final likedPosts = await supabase
          .from('likes')
          .select('posts!inner(*)')
          .eq('user_id', userId)
          .order('created_at', ascending: false);
      
      if (!mounted) return [];

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
          itemCount: posts.length,
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
          itemBuilder: (context, index) {
            return _buildPostCard(posts[index]);
          },
        );
      },
    );
  }


  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text(title), backgroundColor: Colors.teal),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    
    return Scaffold(
      body: Column( // Use Column to stack the scrollable view, the edit button, and the logout area
        children: [
          Expanded( // The scrollable content (AppBar and TabBarView) goes here
            child: NestedScrollView(
              headerSliverBuilder: (context, innerBoxIsScrolled) {
                return <Widget>[
                  SliverAppBar(
                    title: Text(username ?? title),
                    backgroundColor: Colors.teal,
                    pinned: true,
                    floating: true,
                    snap: true,
                    expandedHeight: 240.0, // Reduced height
                    forceElevated: innerBoxIsScrolled,
                    
                    flexibleSpace: FlexibleSpaceBar(
                      centerTitle: true,
                      background: Padding(
                        padding: const EdgeInsets.only(top: 80.0, left: 16, right: 16),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            // Avatar
                            CircleAvatar(
                              radius: 40,
                              backgroundImage: (avatarUrl != null && avatarUrl!.isNotEmpty)
                                  ? NetworkImage(avatarUrl!)
                                  : null,
                              child: (avatarUrl == null || avatarUrl!.isEmpty)
                                  ? const Icon(Icons.person, size: 40)
                                  : null,
                            ),
                            const SizedBox(height: 8),

                            // Username
                            Text(
                              username ?? 'Loading...',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 4),

                            // Bio
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16.0),
                              child: Text(
                                bio ?? 'No bio yet.',
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontSize: 14, color: Colors.white70),
                              ),
                            ),
                            const SizedBox(height: 16),
                            // Removed Edit Button from FlexibleSpaceBar
                          ],
                        ),
                      ),
                    ),

                    // TabBar is fixed to the bottom of the SliverAppBar
                    bottom: TabBar(
                      controller: _tabController,
                      labelColor: Colors.white,
                      unselectedLabelColor: Colors.teal.shade100,
                      indicatorColor: Colors.white,
                      tabs: const [
                        Tab(icon: Icon(Icons.article), text: 'Posts'),
                        Tab(icon: Icon(Icons.favorite), text: 'Likes'),
                      ],
                    ),
                  ),
                ];
              },
              // The body of NestedScrollView is the TabBarView
              body: TabBarView(
                controller: _tabController,
                children: [
                  // Posts Tab Content
                  RefreshIndicator(
                    onRefresh: _loadProfileAndPosts,
                    child: _buildPostList(_userPostsFuture, 'You haven\'t posted anything yet.'),
                  ),
                  
                  // Liked Posts Tab Content
                  RefreshIndicator(
                    onRefresh: _loadProfileAndPosts,
                    child: _buildPostList(_likedPostsFuture, 'You haven\'t liked any posts yet.'),
                  ),
                ],
              ),
            ),
          ),
          
          // 💡 FIXED Edit Button Section
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: SizedBox(
              width: 150,
              child: ElevatedButton.icon(
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const EditProfilePage(),
                    ),
                  );
                  await _loadProfileAndPosts();
                },
                icon: const Icon(Icons.edit, size: 18),
                label: const Text('Edit Profile'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal.shade50,
                  foregroundColor: Colors.teal.shade800,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                ),
              ),
            ),
          ),

          // 💡 FIXED Logout Button (Moved from original bottomNavigationBar)
          SizedBox(
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: ListTile(
                  leading: const Icon(Icons.logout),
                  title: const Text('Logout'),
                  onTap: _logout,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}