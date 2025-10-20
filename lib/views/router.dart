import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

final router = GoRouter(
  navigatorKey: _rootNavigatorKey,
  routes: []
);