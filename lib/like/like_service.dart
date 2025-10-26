import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LikeService {
  final _supabase = Supabase.instance.client;

  /// Toggles the like status via a PostgreSQL Remote Procedure Call (RPC).
  /// This function handles the like/unlike logic and returns the new count reliably.
  Future<int> toggleLike(String postId, String userId) async {
    if (userId.isEmpty) {
      throw Exception("User must be logged in to like a post.");
    }
    
    try {
      // Call the stored function (RPC)
      final newCount = await _supabase.rpc(
        'toggle_like', // The name of the function created in SQL
        params: {
          'target_post_id': postId,
          'liker_user_id': userId,
        },
      );

      // The RPC returns an integer directly (the new count)
      return newCount as int;

    } on PostgrestException catch (e) {
      debugPrint('Supabase RPC Error toggling like: ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('General Error toggling like: $e');
      rethrow;
    }
  }
}