import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
// Note: selectedPageNotifier was previously used for manual nav state; with go_router we derive the index from the route.

class NavbarWidget extends StatelessWidget {
  const NavbarWidget({super.key});

  @override
  Widget build(BuildContext context) {
    // Map route path to selected index
    final location = GoRouterState.of(context).uri.path;
  int selectedIndex = 0;
  if (location.startsWith('/app/profile')) { selectedIndex = 1; }
  else if (location.startsWith('/app/discover')) { selectedIndex = 2; }
  else if (location.startsWith('/app/map')) { selectedIndex = 3; }

    return NavigationBar(
      destinations: const [
        NavigationDestination(icon: Icon(Icons.home), label: 'home'),
        NavigationDestination(icon: Icon(Icons.person), label: 'profile'),
        NavigationDestination(icon: Icon(Icons.post_add), label: 'discover'),
        NavigationDestination(icon: Icon(Icons.map), label: 'map'),
      ],
      onDestinationSelected: (value) {
        switch (value) {
          case 0:
            context.go('/app/home');
            break;
          case 1:
            context.go('/app/profile');
            break;
          case 2:
            context.go('/app/discover');
            break;
          case 3:
            context.go('/app/map');
            break;
        }
      },
      selectedIndex: selectedIndex,
    );
  }
}