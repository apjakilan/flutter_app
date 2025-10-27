import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_app/like/like_service.dart';
import 'package:flutter_app/views/widgets/create_post_fab.dart';

class HomePage extends StatefulWidget {
    const HomePage({super.key});

    @override
    State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
    final supabase = Supabase.instance.client;
    final title = 'Home Page';

    final LikeService _likeService = LikeService();
    final String? _currentUserId = Supabase.instance.client.auth.currentUser?.id;

    // Pagination state
    final List<Map<String, dynamic>> _posts = [];
    final int _limit = 10;
    int _page = 0; // zero-based page index
    bool _isLoading = false;
    bool _hasMore = true;
    late final ScrollController _scrollController;

    @override
    void initState() {
        super.initState();
        _scrollController = ScrollController()..addListener(_onScroll);
        _fetchPostsPage(refresh: true);
    }

    @override
    void dispose() {
        _scrollController.removeListener(_onScroll);
        _scrollController.dispose();
        super.dispose();
    }

    void _onScroll() {
        if (!_hasMore || _isLoading) return;
        if (_scrollController.position.extentAfter < 300) {
            _fetchPostsPage();
        }
    }

    Future<void> _fetchPostsPage({bool refresh = false}) async {
        if (_isLoading) return;
        setState(() {
            _isLoading = true;
        });

        if (refresh) {
            _page = 0;
            _hasMore = true;
        }

        final from = _page * _limit;
        final to = from + _limit - 1;

        try {
            final raw = await supabase
                .from('posts')
                .select()
                .order('created_at', ascending: false)
                .range(from, to);

            final pagePosts = List<Map<String, dynamic>>.from(raw as List);

            if (refresh) {
                _posts.clear();
            }

            if (pagePosts.length < _limit) {
                _hasMore = false;
            }

            // Attach profiles and like data similar to previous implementation
            if (pagePosts.isNotEmpty) {
                final postIds = pagePosts.map((p) => p['id'] as String).toList();
                final userIds = pagePosts.map((p) => p['user_id']).whereType<String>().toSet().toList();

                // batch fetch profiles
                final profiles = await supabase
                    .from('profile')
                    .select('id, username, avatar_url')
                    .inFilter('id', userIds);
                final profileMap = {for (var p in profiles) p['id']: p};

                // fetch likes
                final allLikesResponse = await supabase
                    .from('likes')
                    .select('post_id, user_id')
                    .inFilter('post_id', postIds);
                final allLikesData = allLikesResponse as List<dynamic>;

                final Map<String, int> likeCounts = {};
                final Map<String, bool> userLikedStatus = {};

                for (final like in allLikesData) {
                    final postId = like['post_id'] as String;
                    likeCounts.update(postId, (value) => value + 1, ifAbsent: () => 1);
                    if (like['user_id'] == _currentUserId) {
                        userLikedStatus[postId] = true;
                    }
                }

                for (final post in pagePosts) {
                    final postId = post['id'] as String;
                    post['profile'] = profileMap[post['user_id']];
                    post['like_count'] = likeCounts[postId] ?? 0;
                    post['user_liked'] = userLikedStatus[postId] ?? false;
                }
            }

            setState(() {
                _posts.addAll(pagePosts);
                _page += 1;
            });
        } catch (e, st) {
            debugPrint('Error fetching posts page: $e\n$st');
            if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Failed to load posts.')),
                );
            }
        } finally {
            if (mounted) setState(() => _isLoading = false);
        }
    }

    @override
    Widget build(BuildContext context) {
        return Scaffold(
            appBar: AppBar(
                title: Text(title),
                backgroundColor: Colors.teal,
            ),
            floatingActionButton: const CreatePostFab(),
            body: _isLoading && _posts.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : _posts.isEmpty
                    ? const Center(
                        child: Text(
                            'No posts yet. Be the first to share something!',
                            style: TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                    )
                    : RefreshIndicator(
                        onRefresh: () async {
                            await _fetchPostsPage(refresh: true);
                        },
                        child: ListView.builder(
                            controller: _scrollController,
                            itemCount: _posts.length + (_hasMore ? 1 : 0),
                            itemBuilder: (context, index) {
                                if (index >= _posts.length) {
                                    // loading indicator at the bottom
                                    return const Padding(
                                        padding: EdgeInsets.symmetric(vertical: 16.0),
                                        child: Center(child: CircularProgressIndicator()),
                                    );
                                }

                                final post = _posts[index];
                                final postId = post['id'] as String;
                                final profile = post['profile'] ?? {};
                                final username = profile['username'] ?? 'Unknown';
                                final avatarUrl = profile['avatar_url'];
                                final content = post['content'] ?? '';
                                final imageUrl = post['image_url'] as String?;
                                final createdAt = post['created_at'] ?? '';
                                final userId = post['user_id'] as String?;

                                final int likeCount = post['like_count'] as int? ?? 0;
                                final bool userLiked = post['user_liked'] as bool? ?? false;

                                return Card(
                                    margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    elevation: 3,
                                    shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                    ),
                                    // 💡 NEW: InkWell to make the entire card content clickable
                                    child: InkWell(
                                        onTap: () {
                                            // Navigate to the post detail page
                                            context.push('/post_detail/$postId');
                                        },
                                        child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                                // User info and text content (kept within a GestureDetector/InkWell for profile nav)
                                                ListTile(
                                                    onTap: () {
                                                        if (userId != null && userId.isNotEmpty) {
                                                            context.push('/guest/$userId');
                                                        }
                                                    },
                                                    leading: CircleAvatar(
                                                        backgroundImage: avatarUrl != null && avatarUrl != ''
                                                            ? NetworkImage(avatarUrl)
                                                            : const AssetImage('assets/default_avatar.png')
                                                                  as ImageProvider,
                                                    ),
                                                    title: Text(
                                                        username,
                                                        style: const TextStyle(
                                                            fontWeight: FontWeight.bold,
                                                            fontSize: 16,
                                                        ),
                                                    ),
                                                    subtitle: Padding(
                                                        padding: const EdgeInsets.only(top: 4.0),
                                                        child: Text(content),
                                                    ),
                                                    trailing: Text(
                                                        createdAt != ''
                                                            ? DateTime.parse(createdAt).toLocal().toString().substring(0, 16)
                                                            : '',
                                                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                                                    ),
                                                ),

                                                // Image display
                                                if (imageUrl != null && imageUrl.isNotEmpty)
                                                    Padding(
                                                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                                                        child: ClipRRect(
                                                            borderRadius: BorderRadius.circular(8.0),
                                                            child: Image.network(
                                                                imageUrl,
                                                                fit: BoxFit.cover,
                                                                width: double.infinity,
                                                                loadingBuilder: (context, child, loadingProgress) {
                                                                    if (loadingProgress == null) return child;
                                                                    return const SizedBox(
                                                                        height: 150,
                                                                        child: Center(child: CircularProgressIndicator()),
                                                                    );
                                                                },
                                                                errorBuilder: (context, error, stackTrace) {
                                                                    debugPrint('Image load failed for URL: $imageUrl. Error: $error');
                                                                    return const SizedBox(
                                                                        height: 150,
                                                                        child: Center(child: Text('Failed to load image')),
                                                                    );
                                                                },
                                                            ),
                                                        ),
                                                    ),

                                                // Like and Comment buttons
                                                Padding(
                                                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                                                    child: Row(
                                                        children: [
                                                            IconButton(
                                                                icon: Icon(
                                                                    userLiked ? Icons.favorite : Icons.favorite_border,
                                                                    color: userLiked ? Colors.red : Colors.grey,
                                                                ),
                                                                onPressed: () async {
                                                                    if (_currentUserId == null) {
                                                                        if (context.mounted) {
                                                                            ScaffoldMessenger.of(context).showSnackBar(
                                                                                const SnackBar(content: Text('Please log in to like a post.')),
                                                                            );
                                                                        }
                                                                        return;
                                                                    }
                                                                    try {
                                                                        await _likeService.toggleLike(postId, _currentUserId);
                                                                        // Refresh current loaded pages to reflect like change
                                                                        if (mounted) {
                                                                            setState(() {
                                                                                _posts.clear();
                                                                                _page = 0;
                                                                                _hasMore = true;
                                                                            });
                                                                            await _fetchPostsPage(refresh: true);
                                                                        }
                                                                    } catch (e) {
                                                                        debugPrint('Error toggling like: $e');
                                                                        if (context.mounted) {
                                                                            ScaffoldMessenger.of(context).showSnackBar(
                                                                                const SnackBar(content: Text('Failed to update like status.')),
                                                                            );
                                                                        }
                                                                    }
                                                                },
                                                            ),
                                                            Text('$likeCount likes'),
                                                            
                                                            // 💡 NEW: Comment Action Button
                                                            const SizedBox(width: 16),
                                                            TextButton.icon(
                                                                icon: const Icon(Icons.comment_outlined, color: Colors.grey),
                                                                label: const Text('Comments'),
                                                                onPressed: () {
                                                                    // Navigate to the post detail page
                                                                    context.push('/post_detail/$postId');
                                                                },
                                                            ),
                                                        ],
                                                    ),
                                                ),
                                            ],
                                        ),
                                    ),
                                );
                            },
                        ),
                    ),
            );
    }
}