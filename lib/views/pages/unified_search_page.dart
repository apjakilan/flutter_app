import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
// Import your navigation targets
import 'package:flutter_app/views/pages/guest_profile_page.dart'; 
// Assuming you have a PostDetailPage or similar, though ListTiles will suffice for now

class UnifiedSearchPage extends StatefulWidget {
  const UnifiedSearchPage({super.key});

  @override
  State<UnifiedSearchPage> createState() => _UnifiedSearchPageState();
}

class _UnifiedSearchPageState extends State<UnifiedSearchPage> {
  final supabase = Supabase.instance.client;
  final TextEditingController _searchController = TextEditingController();
  
  // State to hold search results
  List<Map<String, dynamic>> _userResults = [];
  List<Map<String, dynamic>> _postResults = [];
  bool _isSearching = false;
  String _currentSearchTerm = '';

  @override
  void initState() {
    super.initState();
    // Use a debounce or a short delay to prevent querying on every single keystroke
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  // Simple Debounce function using Future.delayed
  void _onSearchChanged() {
    final newSearchTerm = _searchController.text.trim();
    if (newSearchTerm == _currentSearchTerm) return;

    _currentSearchTerm = newSearchTerm;
    
    // Only search if the query is 3 or more characters long
    if (newSearchTerm.length >= 3) {
      // Use a short delay to wait for the user to finish typing
      Future.delayed(const Duration(milliseconds: 500), () {
        // Re-check the term in case the user typed more while waiting
        if (_searchController.text.trim() == newSearchTerm) {
          _performUnifiedSearch(newSearchTerm);
        }
      });
    } else if (newSearchTerm.isEmpty) {
      setState(() {
        _userResults = [];
        _postResults = [];
      });
    }
  }

  // --- Unified Search Logic ---
  Future<void> _performUnifiedSearch(String query) async {
    if (!mounted) return;
    
    setState(() {
      _isSearching = true;
    });

    try {
      // 1. Search for Profiles (Users)
      final profileSearchFuture = supabase
          .from('profile')
          .select('id, username, avatar_url')
          .ilike('username', '%$query%') 
          .limit(10); // Limit user results

      // 2. Search for Posts
      // We join 'posts' with 'profile' to get the username/avatar for display
      final postSearchFuture = supabase
          .from('posts')
          .select('*, profile!inner(username, avatar_url)') // Join posts with profile
          // Search in the 'content' column of the posts table
          .ilike('content', '%$query%')
          .order('created_at', ascending: false)
          .limit(10); // Limit post results

      // Wait for both queries to complete
      final results = await Future.wait([profileSearchFuture, postSearchFuture]);
      
      if (!mounted) return;

      setState(() {
        _userResults = List<Map<String, dynamic>>.from(results[0]);
        // The post results will be a list of maps, where 'profile' is a nested map
        _postResults = List<Map<String, dynamic>>.from(results[1]);
        _isSearching = false;
      });
      
    } catch (e) {
      debugPrint('Error performing unified search: $e');
      if (!mounted) return;
      setState(() {
        _isSearching = false;
        _userResults = []; 
        _postResults = [];
      });
    }
  }
  
  // --- UI Builder ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Search'),
        backgroundColor: Colors.teal,
        // The search bar will be in the body for better integration and focus control
        // but we'll include it here for the same look as the previous example.
      ),
      body: Column(
        children: [
          // Search Text Field in the Body
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search users or posts...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _currentSearchTerm.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _userResults = [];
                            _postResults = [];
                            _currentSearchTerm = '';
                          });
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25.0),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.grey.shade200,
              ),
            ),
          ),
          Expanded(
            child: _buildResultsBody(),
          ),
        ],
      ),
    );
  }

  Widget _buildResultsBody() {
    if (_isSearching) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_currentSearchTerm.isEmpty) {
      return const Center(
        child: Text('Start typing to search users and posts.', style: TextStyle(color: Colors.grey, fontSize: 16)),
      );
    }

    if (_userResults.isEmpty && _postResults.isEmpty) {
      return Center(
        child: Text('No results found for "$_currentSearchTerm".', style: const TextStyle(color: Colors.grey, fontSize: 16)),
      );
    }

    return ListView(
      children: [
        // --- User Results Section ---
        if (_userResults.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text(
              'Users (${_userResults.length})',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.teal),
            ),
          ),
        ..._userResults.map(_buildUserListTile).toList(),
        
        const Divider(),

        // --- Post Results Section ---
        if (_postResults.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text(
              'Posts (${_postResults.length})',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.teal),
            ),
          ),
        ..._postResults.map(_buildPostListTile).toList(),
        
        const SizedBox(height: 50),
      ],
    );
  }

  // Helper Widget: User Tile
  Widget _buildUserListTile(Map<String, dynamic> profile) {
    final userId = profile['id'] as String;
    final username = profile['username'] as String?;
    final avatarUrl = profile['avatar_url'] as String?;

    return ListTile(
      leading: CircleAvatar(
        backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
        child: (avatarUrl == null || avatarUrl.isEmpty) ? const Icon(Icons.person) : null,
      ),
      title: Text(username ?? 'Unknown User'),
      subtitle: const Text('Tap to view profile'),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => GuestProfilePage(userId: userId),
          ),
        );
      },
    );
  }

  // Helper Widget: Post Tile
  Widget _buildPostListTile(Map<String, dynamic> post) {
    final content = post['content'] as String? ?? 'No Content';
    final profile = post['profile'] as Map<String, dynamic>?;
    final username = profile?['username'] as String? ?? 'Unknown';
    final avatarUrl = profile?['avatar_url'] as String?;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
          child: (avatarUrl == null || avatarUrl.isEmpty) ? const Icon(Icons.person) : null,
        ),
        title: Text(content, maxLines: 2, overflow: TextOverflow.ellipsis),
        subtitle: Text('Posted by: $username'),
        onTap: () {
          // You might navigate to a Post Details Page here, or just show a snackbar
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Viewing post details...')),
          );
        },
      ),
    );
  }
}