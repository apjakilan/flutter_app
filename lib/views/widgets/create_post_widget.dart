import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CreatePostWidget extends StatefulWidget {
  const CreatePostWidget({super.key});

  @override
  State<CreatePostWidget> createState() => _CreatePostWidgetState();
}

class _CreatePostWidgetState extends State<CreatePostWidget> {
  final _controller = TextEditingController();
  final supabase = Supabase.instance.client;
  bool _isPosting = false;

  Future<void> _createPost() async {
    final user = supabase.auth.currentUser;
    if (user == null || _controller.text.trim().isEmpty) return;

    setState(() => _isPosting = true);

    try {
      await supabase.from('posts').insert({
        'user_id': user.id,
        'content': _controller.text.trim(),
      });

      _controller.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Post created!')),
      );
      Navigator.pop(context); // Close dialog/page if you want
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      setState(() => _isPosting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextField(
          controller: _controller,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'What’s on your mind?',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        ElevatedButton(
          onPressed: _isPosting ? null : _createPost,
          child: _isPosting
              ? const CircularProgressIndicator(color: Colors.white)
              : const Text('Post'),
        ),
      ],
    );
  }
}