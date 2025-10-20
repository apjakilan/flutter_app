import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final title = 'Home Page';

  // ✅ Stream posts joined with profile info
  final _postsStream = Supabase.instance.client
      .from('posts')
      .stream(primaryKey: ['id'])
      .order('created_at', ascending: false)
      .map((posts) async {
    // For each post, fetch profile data
    final supabase = Supabase.instance.client;
    for (final post in posts) {
      final profile = await supabase
          .from('profile')
          .select('username, avatar_url')
          .eq('id', post['user_id'])
          .single();
      post['profile'] = profile;
    }
    return posts;
  }).asyncMap((posts) async => await posts);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title), backgroundColor: Colors.teal),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _postsStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting ||
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final posts = snapshot.data!;
          if (posts.isEmpty) {
            return const Center(
                child: Text('No posts yet. Be the first to share something!'));
          }

          return ListView.builder(
            itemCount: posts.length,
            itemBuilder: (context, index) {
              final post = posts[index];
              final profile = post['profile'] ?? {};
              final username = profile['username'] ?? 'Unknown';
              final avatarUrl = profile['avatar_url'];

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                elevation: 3,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundImage: avatarUrl != null
                        ? NetworkImage(avatarUrl)
                        : const AssetImage('assets/default_avatar.png')
                            as ImageProvider,
                  ),
                  title: Text(
                    username,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  subtitle: Text(post['content'] ?? ''),
                  trailing: Text(
                    post['created_at'] != null
                        ? DateTime.parse(post['created_at'])
                            .toLocal()
                            .toString()
                            .substring(0, 16)
                        : '',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
