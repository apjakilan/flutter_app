import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
// 🚀 THIS IS THE IMPORTANT CHANGE: Import the correct file!
import 'package:flutter_app/like/like_service.dart';

// ❌ DELETE THE FOLLOWING STUB CLASS:
/*
class LikeService {
    Future<void> toggleLike(String postId, String userId) async {
        // TODO: implement like toggle logic (e.g., call Supabase RPC or upsert)
        throw UnimplementedError('LikeService.toggleLike is not implemented');
    }
}
*/

class HomePage extends StatefulWidget {
    const HomePage({super.key});

    @override
    State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
    final supabase = Supabase.instance.client;
    final title = 'Home Page';

    // Initialize service and current user id
    final LikeService _likeService = LikeService();
    final String? _currentUserId = Supabase.instance.client.auth.currentUser?.id;

    late Stream<List<Map<String, dynamic>>> _postsStream;

    @override
    void initState() {
        super.initState();
        _postsStream = _getRealtimePosts();
    }

    // Creates a realtime stream of posts, joins with profile info, and fetches like data
    Stream<List<Map<String, dynamic>>> _getRealtimePosts() {
        return supabase
            .from('posts')
            .stream(primaryKey: ['id'])
            .order('created_at', ascending: false)
            .asyncMap((posts) async {
                if (posts.isEmpty) return posts;

                // Collect all post IDs and unique user IDs
                final postIds = posts.map((p) => p['id'] as String).toList();
                final userIds = posts.map((p) => p['user_id']).toSet().toList();

                // 1. Fetch related profiles
                final profiles = await supabase
                    .from('profile')
                    .select('id, username, avatar_url')
                    .inFilter('id', userIds);
                final profileMap = {for (var p in profiles) p['id']: p};

                // 2. Fetch likes data for the displayed posts
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

                // 3. Attach profiles and like data to posts
                for (final post in posts) {
                    final postId = post['id'] as String;
                    post['profile'] = profileMap[post['user_id']];
                    post['like_count'] = likeCounts[postId] ?? 0;
                    post['user_liked'] = userLikedStatus[postId] ?? false;
                }

                return posts;
            });
    }

    @override
    Widget build(BuildContext context) {
        return Scaffold(
            appBar: AppBar(
                title: Text(title),
                backgroundColor: Colors.teal,
            ),
            body: StreamBuilder<List<Map<String, dynamic>>>(
                stream: _postsStream,
                builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting ||
                        !snapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                    }

                    if (snapshot.hasError) {
                        return Center(
                            child: Text(
                                'Error loading posts: ${snapshot.error}',
                                style: const TextStyle(color: Colors.red),
                            ),
                        );
                    }

                    final posts = snapshot.data!;
                    if (posts.isEmpty) {
                        return const Center(
                            child: Text(
                                'No posts yet. Be the first to share something!',
                                style: TextStyle(fontSize: 16, color: Colors.grey),
                            ),
                        );
                    }

                    return RefreshIndicator(
                        onRefresh: () async {
                            setState(() {
                                _postsStream = _getRealtimePosts();
                            });
                        },
                        child: ListView.builder(
                            itemCount: posts.length,
                            itemBuilder: (context, index) {
                                final post = posts[index];
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
                                    margin:
                                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    elevation: 3,
                                    shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                            // User info and text content
                                                ListTile(
                                                onTap: () {
                                                    if (userId != null && userId.isNotEmpty) {
                                                        // Navigate using go_router to the guest profile route
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
                                                        ? DateTime.parse(createdAt)
                                                                .toLocal()
                                                                .toString()
                                                                .substring(0, 16)
                                                        : '',
                                                    style:
                                                        const TextStyle(fontSize: 12, color: Colors.grey),
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
                                                                    child: Center(
                                                                        child: Text('Failed to load image'),
                                                                    ),
                                                                );
                                                            },
                                                        ),
                                                    ),
                                                ),

                                            // Like button and count
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
                                                                    ScaffoldMessenger.of(context).showSnackBar(
                                                                        const SnackBar(content: Text('Please log in to like a post.')),
                                                                    );
                                                                    return;
                                                                }
                                                                try {
                                                                    // The toggleLike RPC in your service returns the new count (int).
                                                                    // We don't need to use the return value here, as we reload the stream.
                                                                    await _likeService.toggleLike(postId, _currentUserId);
                                                                    
                                                                    // Reload the stream to fetch the updated count and user_liked status.
                                                                    setState(() {
                                                                        _postsStream = _getRealtimePosts();
                                                                    });
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
                                                    ],
                                                ),
                                            ),
                                        ],
                                    ),
                                );
                            },
                        ),
                    );
                },
            ),
        );
    }
}