import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_app/views/widgets/create_post_fab.dart';
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

  // Pagination state for user's posts
  final List<Map<String, dynamic>> _userPosts = [];
  int _userPostsPage = 0;
  bool _userPostsHasMore = true;
  bool _userPostsLoading = false;

  // Pagination state for liked posts
  final List<Map<String, dynamic>> _likedPosts = [];
  int _likedPostsPage = 0;
  bool _likedPostsHasMore = true;
  bool _likedPostsLoading = false;

  String? currentUserId;
  
  late ScrollController _userPostsController;
  late ScrollController _likedPostsController;

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _userPostsController = ScrollController();
    _likedPostsController = ScrollController();
    _userPostsController.addListener(() {
      if (_userPostsController.position.pixels >= _userPostsController.position.maxScrollExtent - 200) {
        if (!_userPostsLoading && _userPostsHasMore) _fetchUserPostsPage();
      }
    });
    _likedPostsController.addListener(() {
      if (_likedPostsController.position.pixels >= _likedPostsController.position.maxScrollExtent - 200) {
        if (!_likedPostsLoading && _likedPostsHasMore) _fetchLikedPostsPage();
      }
    });

    _loadProfileAndPosts();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _userPostsController.dispose();
    _likedPostsController.dispose();
    super.dispose();
  }

  Widget _buildPaginatedPostList({
    required List<Map<String, dynamic>> posts,
    required ScrollController controller,
    required bool isLoading,
    required bool hasMore,
    required String emptyMessage,
  }) {
    if (posts.isEmpty && isLoading) return const Center(child: CircularProgressIndicator());
    if (posts.isEmpty && !isLoading) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(emptyMessage),
        ),
      );
    }

    return ListView.builder(
      controller: controller,
      itemCount: posts.length + (hasMore ? 1 : 0),
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
      itemBuilder: (context, index) {
        if (index >= posts.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16.0),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final post = posts[index];
        return InkWell(
          onTap: () {
            final postId = post['id'] as String?;
            if (postId != null) context.push('/post_detail/$postId');
          },
          child: _buildPostCard(post),
        );
      },
    );
  }

  Future<void> _loadProfileAndPosts() async {
    if (!mounted) return;
    await _loadProfile();
    if (mounted) {
      // initialize paginated lists
      setState(() {
        _userPosts.clear();
        _likedPosts.clear();
        _userPostsPage = 0;
        _likedPostsPage = 0;
        _userPostsHasMore = true;
        _likedPostsHasMore = true;
      });
      await _fetchUserPostsPage(refresh: true);
      await _fetchLikedPostsPage(refresh: true);
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

  // The following paginated fetch methods are used by the UI
  Future<void> _fetchUserPostsPage({bool refresh = false}) async {
    if (_userPostsLoading) return;
    setState(() => _userPostsLoading = true);
    if (refresh) {
      _userPostsPage = 0;
      _userPostsHasMore = true;
    }
    final userId = currentUserId ?? supabase.auth.currentUser?.id;
    if (userId == null) {
      setState(() => _userPostsLoading = false);
      return;
    }

    const limit = 10;
    final from = _userPostsPage * limit;
    final to = from + limit - 1;

    try {
      final raw = await supabase
          .from('posts')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .range(from, to);
      final page = List<Map<String, dynamic>>.from(raw as List);
      if (refresh) _userPosts.clear();
      if (page.length < limit) _userPostsHasMore = false;

      if (page.isNotEmpty) {
        final postIds = page.map((p) => p['id'] as String).toList();
        final likesRaw = await supabase.from('likes').select('post_id, user_id').inFilter('post_id', postIds);
        final likeData = likesRaw as List<dynamic>;
        final Map<String, int> likeCounts = {};
        final Map<String, bool> userLiked = {};
        for (final like in likeData) {
          final pid = like['post_id'] as String;
          likeCounts.update(pid, (v) => v + 1, ifAbsent: () => 1);
          if (like['user_id'] == currentUserId) userLiked[pid] = true;
        }
        for (final p in page) {
          final pid = p['id'] as String;
          p['like_count'] = likeCounts[pid] ?? 0;
          p['user_liked'] = userLiked[pid] ?? false;
        }
      }

      setState(() {
        _userPosts.addAll(page);
        _userPostsPage += 1;
      });
    } catch (e, st) {
      debugPrint('Error fetching user posts page: $e\n$st');
    } finally {
      if (mounted) setState(() => _userPostsLoading = false);
    }
  }

  Future<void> _fetchLikedPostsPage({bool refresh = false}) async {
    if (_likedPostsLoading) return;
    setState(() => _likedPostsLoading = true);
    if (refresh) {
      _likedPostsPage = 0;
      _likedPostsHasMore = true;
    }
    final userId = currentUserId ?? supabase.auth.currentUser?.id;
    if (userId == null) {
      setState(() => _likedPostsLoading = false);
      return;
    }

    const limit = 10;
    final from = _likedPostsPage * limit;
    final to = from + limit - 1;

    try {
      final raw = await supabase
          .from('likes')
          .select('posts(*)')
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .range(from, to);
      final page = (raw as List).map<Map<String, dynamic>>((e) => e['posts'] as Map<String, dynamic>).toList();
      if (refresh) _likedPosts.clear();
      if (page.length < limit) _likedPostsHasMore = false;

      if (page.isNotEmpty) {
        final postIds = page.map((p) => p['id'] as String).toList();
        final likesRaw = await supabase.from('likes').select('post_id, user_id').inFilter('post_id', postIds);
        final likeData = likesRaw as List<dynamic>;
        final Map<String, int> likeCounts = {};
        final Map<String, bool> userLiked = {};
        for (final like in likeData) {
          final pid = like['post_id'] as String;
          likeCounts.update(pid, (v) => v + 1, ifAbsent: () => 1);
          if (like['user_id'] == currentUserId) userLiked[pid] = true;
        }
        for (final p in page) {
          final pid = p['id'] as String;
          p['like_count'] = likeCounts[pid] ?? 0;
          p['user_liked'] = userLiked[pid] ?? false;
        }
      }

      setState(() {
        _likedPosts.addAll(page);
        _likedPostsPage += 1;
      });
    } catch (e, st) {
      debugPrint('Error fetching liked posts page: $e\n$st');
    } finally {
      if (mounted) setState(() => _likedPostsLoading = false);
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

  


  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text(title), backgroundColor: Colors.teal),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    
    return Scaffold(
      floatingActionButton: const CreatePostFab(),
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
                            const SizedBox(height: 12),
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
                      tabs: [
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
                    child: _buildPaginatedPostList(
                      posts: _userPosts,
                      controller: _userPostsController,
                      isLoading: _userPostsLoading,
                      hasMore: _userPostsHasMore,
                      emptyMessage: 'You haven\'t posted anything yet.',
                    ),
                  ),
                  
                  // Liked Posts Tab Content
                  RefreshIndicator(
                    onRefresh: _loadProfileAndPosts,
                    child: _buildPaginatedPostList(
                      posts: _likedPosts,
                      controller: _likedPostsController,
                      isLoading: _likedPostsLoading,
                      hasMore: _likedPostsHasMore,
                      emptyMessage: 'You haven\'t liked any posts yet.',
                    ),
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
                  await context.push('/edit-profile');
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