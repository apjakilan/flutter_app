import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final supabase = Supabase.instance.client;
  final title = 'Home Page';

  late final Stream<List<Map<String, dynamic>>> _postsStream;

  @override
  void initState() {
    super.initState();
    _postsStream = _getRealtimePosts();
  }

  /// ✅ Creates a realtime stream of posts and joins with profile info
  Stream<List<Map<String, dynamic>>> _getRealtimePosts() {
    return supabase
        .from('posts')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false)
        .asyncMap((posts) async {
      if (posts.isEmpty) return posts;

      // Collect unique user IDs
      final userIds = posts.map((p) => p['user_id']).toSet().toList();

      // Fetch all related profiles in a single query
      final profiles = await supabase
          .from('profile')
          .select('id, username, avatar_url')
          .inFilter('id', userIds);

      // Map each user_id to their profile
      final profileMap = {
        for (var p in profiles) p['id']: p,
      };

      // Attach profiles to posts
      for (final post in posts) {
        post['profile'] = profileMap[post['user_id']];
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
                _postsStream = _getRealtimePosts(); // reload stream manually
              });
            },
            child: ListView.builder(
              itemCount: posts.length,
              itemBuilder: (context, index) {
                final post = posts[index];
                final profile = post['profile'] ?? {};
                final username = profile['username'] ?? 'Unknown';
                final avatarUrl = profile['avatar_url'];
                final content = post['content'] ?? '';
                final createdAt = post['created_at'] ?? '';

                return Card(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  elevation: 3,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
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
                );
              },
            ),
          );
        },
      ),
    );
  }
}
