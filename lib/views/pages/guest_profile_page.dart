import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class GuestProfilePage extends StatefulWidget {
  final String userId;

  const GuestProfilePage({super.key, required this.userId});

  @override
  State<GuestProfilePage> createState() => _GuestProfilePageState();
}

class _GuestProfilePageState extends State<GuestProfilePage>
    with SingleTickerProviderStateMixin {
  final supabase = Supabase.instance.client;
  String? avatarUrl;
  String? username;
  String? bio;
  bool isLoading = true;

  Future<List<Map<String, dynamic>>>? _userPostsFuture;
  Future<List<Map<String, dynamic>>>? _likedPostsFuture;

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadProfileAndPosts(widget.userId);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // --- Profile & Posts Loading (No change) ---
  Future<void> _loadProfileAndPosts(String userId) async {
    if (!mounted) return;

    await _loadProfile(userId);

    if (mounted) {
      setState(() {
        _userPostsFuture = _fetchUserPosts(userId);
        _likedPostsFuture = _fetchLikedPosts(userId);
      });
    }
  }

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

  Future<List<Map<String, dynamic>>> _fetchLikedPosts(String userId) async {
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
      debugPrint('Error fetching guest liked posts: $e');
      return Future.error('Failed to load liked posts');
    }
  }

  // --- Widget for a Single Post Card (No change) ---
  Widget _buildPostCard(Map<String, dynamic> post) {
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
              borderRadius:
                  const BorderRadius.vertical(bottom: Radius.circular(10)),
              child: Image.network(
                imageUrl,
                fit: BoxFit.cover,
                width: double.infinity,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return const SizedBox(
                      height: 200,
                      child: Center(child: CircularProgressIndicator()));
                },
                errorBuilder: (context, error, stackTrace) {
                  return const SizedBox(
                      height: 100,
                      child: Center(
                          child: Text('Image failed to load 😔')));
                },
              ),
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  // --- Widget to display the Future list of posts (Slight change for NestedScrollView context) ---
  Widget _buildPostList(
      Future<List<Map<String, dynamic>>>? future, String emptyMessage) {
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

        // Return ListView.builder, which is now the main scrollable content
        return ListView.builder(
          // Important: Must NOT use NeverScrollableScrollPhysics inside NestedScrollView body
          // The NestedScrollView handles the scrolling coordination.
          itemCount: posts.length,
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
          itemBuilder: (context, index) {
            return _buildPostCard(posts[index]);
          },
        );
      },
    );
  }

  // --- 💡 MAIN BUILD METHOD (Refactored to use NestedScrollView) ---
  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        appBar: AppBar(
            title: Text(username ?? 'Loading Profile'), backgroundColor: Colors.teal),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      // 💡 REPLACED the top-level body with NestedScrollView
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return <Widget>[
            SliverAppBar(
              title: Text(username ?? 'User Profile'),
              backgroundColor: Colors.teal,
              pinned: true, // Keep the TabBar at the top when scrolling
              floating: true,
              snap: true,
              expandedHeight: 200.0, // Control the height of the profile header
              forceElevated: innerBoxIsScrolled,

              flexibleSpace: FlexibleSpaceBar(
                centerTitle: true,
                // The profile details are placed here
                background: Padding(
                  padding: const EdgeInsets.only(top: 80.0, left: 16, right: 16),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      // Avatar
                      CircleAvatar(
                        radius: 40,
                        backgroundImage:
                            (avatarUrl != null && avatarUrl!.isNotEmpty)
                                ? NetworkImage(avatarUrl!)
                                : null,
                        child: (avatarUrl == null || avatarUrl!.isEmpty)
                            ? const Icon(Icons.person, size: 40)
                            : null,
                      ),
                      const SizedBox(height: 8),

                      // Username
                      Text(
                        username ?? 'User Profile',
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
                          bio ?? 'This user has not set a bio yet.',
                          textAlign: TextAlign.center,
                          style:
                              const TextStyle(fontSize: 14, color: Colors.white70),
                        ),
                      ),
                      const SizedBox(height: 16),
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
              onRefresh: () => _loadProfileAndPosts(widget.userId),
              child: _buildPostList(_userPostsFuture, 'This user hasn\'t posted anything yet.'),
            ),

            // Liked Posts Tab Content
            RefreshIndicator(
              onRefresh: () => _loadProfileAndPosts(widget.userId),
              child: _buildPostList(_likedPostsFuture, 'This user hasn\'t liked any posts yet.'),
            ),
          ],
        ),
      ),
    );
  }
}