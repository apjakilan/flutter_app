import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
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
        if (!_userPostsLoading && _userPostsHasMore) _fetchUserPostsPage(widget.userId);
      }
    });
    _likedPostsController.addListener(() {
      if (_likedPostsController.position.pixels >= _likedPostsController.position.maxScrollExtent - 200) {
        if (!_likedPostsLoading && _likedPostsHasMore) _fetchLikedPostsPage(widget.userId);
      }
    });

    _loadProfileAndPosts(widget.userId);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _userPostsController.dispose();
    _likedPostsController.dispose();
    super.dispose();
  }

  // --- Profile & Posts Loading (No change) ---
  Future<void> _loadProfileAndPosts(String userId) async {
    if (!mounted) return;

    await _loadProfile(userId);

    if (mounted) {
      setState(() {
        _userPosts.clear();
        _likedPosts.clear();
        _userPostsPage = 0;
        _likedPostsPage = 0;
        _userPostsHasMore = true;
        _likedPostsHasMore = true;
      });
      await _fetchUserPostsPage(userId, refresh: true);
      await _fetchLikedPostsPage(userId, refresh: true);
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

  

  Future<void> _fetchUserPostsPage(String userId, {bool refresh = false}) async {
    if (_userPostsLoading) return;
    setState(() => _userPostsLoading = true);
    if (refresh) {
      _userPostsPage = 0;
      _userPostsHasMore = true;
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
          if (like['user_id'] == widget.userId) userLiked[pid] = true;
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
      debugPrint('Error fetching guest user posts page: $e\n$st');
    } finally {
      if (mounted) setState(() => _userPostsLoading = false);
    }
  }

  Future<void> _fetchLikedPostsPage(String userId, {bool refresh = false}) async {
    if (_likedPostsLoading) return;
    setState(() => _likedPostsLoading = true);
    if (refresh) {
      _likedPostsPage = 0;
      _likedPostsHasMore = true;
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
          if (like['user_id'] == widget.userId) userLiked[pid] = true;
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
      debugPrint('Error fetching guest liked posts page: $e\n$st');
    } finally {
      if (mounted) setState(() => _likedPostsLoading = false);
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
              child: _buildPaginatedPostList(
                posts: _userPosts,
                controller: _userPostsController,
                isLoading: _userPostsLoading,
                hasMore: _userPostsHasMore,
                emptyMessage: 'This user hasn\'t posted anything yet.',
              ),
            ),

            // Liked Posts Tab Content
            RefreshIndicator(
              onRefresh: () => _loadProfileAndPosts(widget.userId),
              child: _buildPaginatedPostList(
                posts: _likedPosts,
                controller: _likedPostsController,
                isLoading: _likedPostsLoading,
                hasMore: _likedPostsHasMore,
                emptyMessage: 'This user hasn\'t liked any posts yet.',
              ),
            ),
          ],
        ),
      ),
    );
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
}