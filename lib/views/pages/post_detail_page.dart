// post_detail_page.dart

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timeago/timeago.dart' as timeago;

class PostDetailPage extends StatefulWidget {
  final String postId;

  const PostDetailPage({super.key, required this.postId});

  @override
  State<PostDetailPage> createState() => _PostDetailPageState();
}

class _PostDetailPageState extends State<PostDetailPage> {
  final supabase = Supabase.instance.client;
  final _commentController = TextEditingController();
  final String? _currentUserId = Supabase.instance.client.auth.currentUser?.id;
  
  // Local state to manage loading/busy state of the submit button
  bool _isPostingComment = false;

  late final Future<Map<String, dynamic>?> _postFuture;
  late Stream<List<Map<String, dynamic>>> _commentsStream;

  @override
  void initState() {
    super.initState();
    // Re-initialize the futures/streams if needed
    _initializeData();
  }
  
  void _initializeData() {
    _postFuture = _fetchPostDetails();
    _commentsStream = _getRealtimeComments();
    // Force rebuild to show loading state if called from RefreshIndicator
    if(mounted) setState(() {}); 
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  // 1. Fetch the single post data
  Future<Map<String, dynamic>?> _fetchPostDetails() async {
    try {
      final response = await supabase
          .from('posts')
          .select('*, profile:user_id(username, avatar_url)')
          .eq('id', widget.postId)
          .single();
      
      return response;
    } catch (e) {
      debugPrint('Error fetching post details: $e');
      return null;
    }
  }

  // 2. Setup a realtime stream for comments (OPTIMIZED)
Stream<List<Map<String, dynamic>>> _getRealtimeComments() {
  // Subscribe to realtime events for comments on this post and, on each
  // event, run a full SELECT to fetch the joined/profile data (realtime
  // payloads don't include related rows).
  // Wrap the SELECT in a try/catch so a failing SELECT doesn't close the
  // stream with an error. Instead we emit an empty list and log the issue.
  return supabase
      .from('comments')
      .stream(primaryKey: ['id'])
      .eq('post_id', widget.postId)
      .order('created_at', ascending: true)
      .map((_) {
        // On any change event, return the SELECT Future which fetches the
        // full dataset including the profile join.
        return supabase
            .from('comments')
            .select('*, profile:user_id(username, avatar_url)')
            .eq('post_id', widget.postId)
            .order('created_at', ascending: true)
            .limit(100);
      })
      .asyncMap((future) async {
        try {
          final result = await future;
          // result from supabase SELECT is a List<Map<String, dynamic>>
          return List<Map<String, dynamic>>.from(result as List);
        } catch (e, st) {
          // If the join-based SELECT fails because the DB relationship
          // isn't defined (common when the foreign key is missing),
          // fall back to a two-step fetch: comments then profiles.
          debugPrint('Error fetching comments (SELECT): $e\n$st');
          final err = e.toString();
          if (err.contains('Could not find a relationship') || err.contains('PGRST200')) {
            debugPrint('Falling back to separate comments + profiles fetch (no FK relationship).');
            try {
              final rawComments = await supabase
                  .from('comments')
                  .select()
                  .eq('post_id', widget.postId)
                  .order('created_at', ascending: true)
                  .limit(100);

              final commentsList = List<Map<String, dynamic>>.from(rawComments as List);

              // Batch-fetch profiles for commenters. Some Postgrest clients
              // don't expose a safe 'in' helper; fetch sequentially per id
              // which is simpler and robust (fine for small comment counts).
              final userIds = commentsList.map((c) => c['user_id']).whereType<String>().toSet().toList();
              if (userIds.isEmpty) return commentsList;

              final Map<String, Map<String, dynamic>> profileById = {};
              for (final uid in userIds) {
                try {
                  final raw = await supabase
                      .from('profile')
                      .select('id, username, avatar_url')
                      .eq('id', uid);
                  final list = List<Map<String, dynamic>>.from(raw as List);
                  if (list.isNotEmpty) profileById[uid] = list.first;
                } catch (e3, st3) {
                  debugPrint('Failed to fetch profile for $uid: $e3\n$st3');
                }
              }

              // Merge profile data into each comment under 'profile' key
              final merged = commentsList.map((c) {
                final pid = c['user_id'];
                final profile = profileById[pid] ?? {};
                final m = Map<String, dynamic>.from(c);
                m['profile'] = profile;
                return m;
              }).toList();

              return merged;
            } catch (e2, st2) {
              debugPrint('Fallback comments fetch failed: $e2\n$st2');
              return <Map<String, dynamic>>[];
            }
          }
          // For any other error, emit empty list so UI can recover.
          return <Map<String, dynamic>>[];
        }
      });
}

  // 3. Insert a new comment
  Future<void> _submitComment() async {
    final commentText = _commentController.text.trim();

    if (commentText.isEmpty || _currentUserId == null || _isPostingComment) return;
    
    // Set state to show loading and disable button
    setState(() {
      _isPostingComment = true;
    });

    try {
      await supabase.from('comments').insert({
        'post_id': widget.postId,
        'user_id': _currentUserId,
        'content': commentText,
      });

      _commentController.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Comment posted!')),
        );
      }
    } catch (e) {
      debugPrint('Error submitting comment: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to post comment.')),
        );
      }
    } finally {
      // Re-enable the button regardless of success/failure
      if (mounted) {
        setState(() {
          _isPostingComment = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Post Detail'),
        backgroundColor: Colors.teal,
      ),
      resizeToAvoidBottomInset: true,
      // 💡 WRAP with RefreshIndicator
      body: RefreshIndicator(
        onRefresh: () async {
          _initializeData();
          // The FutureBuilder/StreamBuilder will automatically update
          await _postFuture; 
        },
        child: FutureBuilder<Map<String, dynamic>?>(
          future: _postFuture,
          builder: (context, postSnapshot) {
            if (postSnapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (postSnapshot.hasError || postSnapshot.data == null) {
              return const Center(child: Text('Error loading post.'));
            }

            final post = postSnapshot.data!;
            final profile = post['profile'] ?? {};
            final username = profile['username'] ?? 'Unknown';
            final avatarUrl = profile['avatar_url'];
            final content = post['content'] ?? '';
            final imageUrl = post['image_url'] as String?;
            final createdAt = post['created_at'] ?? '';

            return Column(
              children: [
                // 1. Post Content Header (Scrollable portion)
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ListTile(
                        leading: CircleAvatar(
                          backgroundImage: avatarUrl != null && avatarUrl != ''
                              ? NetworkImage(avatarUrl)
                              : const AssetImage('assets/default_avatar.png') as ImageProvider,
                        ),
                        title: Text(username, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(timeago.format(DateTime.parse(createdAt))),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                        child: Text(content, style: const TextStyle(fontSize: 16)),
                      ),
                      if (imageUrl != null && imageUrl.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8.0),
                            child: Image.network(imageUrl, fit: BoxFit.cover, width: double.infinity),
                          ),
                        ),
                      const Divider(height: 30),
                      const Padding(
                          padding: EdgeInsets.only(left: 16.0, bottom: 8.0),
                          child: Text('Comments', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                      ),
                    ],
                  ),
                ),

                // 2. Comments List (Scrollable part of the body)
                Expanded(
                  child: StreamBuilder<List<Map<String, dynamic>>>(
                    stream: _commentsStream,
                    builder: (context, commentSnapshot) {
                      if (commentSnapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator(strokeWidth: 2));
                      }
                      if (commentSnapshot.hasError) {
                        return Center(child: Text('Error loading comments: ${commentSnapshot.error}'));
                      }
                      if (!commentSnapshot.hasData) {
                        return const Center(child: CircularProgressIndicator(strokeWidth: 2));
                      }

                      final comments = commentSnapshot.data!;
                      if (comments.isEmpty) {
                        return const Center(child: Text('No comments yet.'));
                      }

                      return ListView.builder(
                        itemCount: comments.length,
                        itemBuilder: (context, index) {
                          final comment = comments[index];
                          // Access nested 'profile' data
                          final commentProfile = comment['profile'] as Map<String, dynamic>? ?? {};
                          final commentUsername = commentProfile['username'] ?? 'Anonymous';
                          final commentAvatar = commentProfile['avatar_url'];

                          return ListTile(
                            leading: CircleAvatar(
                              radius: 18,
                              backgroundImage: commentAvatar != null && commentAvatar != ''
                                  ? NetworkImage(commentAvatar)
                                  : const AssetImage('assets/default_avatar.png') as ImageProvider,
                            ),
                            title: Text(commentUsername, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                            subtitle: Text(comment['content']),
                            trailing: Text(
                              timeago.format(DateTime.parse(comment['created_at'])),
                              style: const TextStyle(fontSize: 10, color: Colors.grey),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),

                // 3. Comment Input Field (Sticky at the bottom)
                if (_currentUserId != null)
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _commentController,
                            decoration: InputDecoration(
                              hintText: 'Add a comment...',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(20)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            ),
                            // Disable input while posting
                            enabled: !_isPostingComment,
                          ),
                        ),
                        IconButton(
                          icon: _isPostingComment
                              ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.send, color: Colors.teal),
                          onPressed: _isPostingComment ? null : _submitComment,
                        ),
                      ],
                    ),
                  ),
                if (_currentUserId == null)
                  const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text('Log in to leave a comment.', style: TextStyle(color: Colors.red)),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}