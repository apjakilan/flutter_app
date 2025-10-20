import 'package:flutter/material.dart';

class DiscoverPage extends StatelessWidget {
  const DiscoverPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Discover'),
          centerTitle: true,
          backgroundColor: Colors.teal,
          bottom: const TabBar(
            indicatorColor: Colors.white,
            tabs: [
              Tab(icon: Icon(Icons.place_outlined), text: 'Near you'),
              Tab(icon: Icon(Icons.new_releases_outlined), text: 'Something new'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // Near you tab - empty placeholder
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.place, size: 64, color: theme.colorScheme.primary),
                    const SizedBox(height: 12),
                    Text('Nearby items will appear here', style: theme.textTheme.bodyLarge?.copyWith(color: Colors.grey)),
                  ],
                ),
              ),
            ),

            // Something new tab - empty placeholder
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.new_releases, size: 64, color: theme.colorScheme.primary),
                    const SizedBox(height: 12),
                    Text('New finds will appear here', style: theme.textTheme.bodyLarge?.copyWith(color: Colors.grey)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
