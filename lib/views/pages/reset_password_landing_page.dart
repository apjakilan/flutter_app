import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
// Supabase SDK not required in this landing page; we call the REST endpoint directly.
import 'package:http/http.dart' as http;
import 'dart:convert';

class ResetPasswordLandingPage extends StatefulWidget {
  final String? accessToken;
  const ResetPasswordLandingPage({super.key, this.accessToken});

  @override
  State<ResetPasswordLandingPage> createState() => _ResetPasswordLandingPageState();
}

class _ResetPasswordLandingPageState extends State<ResetPasswordLandingPage> {
  final _passwordController = TextEditingController();
  bool _loading = false;
  String? _accessToken;

  @override
  void initState() {
    super.initState();
    _applyTokenIfPresent();
  }

  Future<void> _applyTokenIfPresent() async {
    // Accept token via three fallbacks, in order:
    // 1. token passed by go_router as query param -> widget.accessToken
    // 2. token available in the current browser URL as access_token
    // 3. token available as `code` (some environments surface it as `code`)
    String? token = widget.accessToken;
    if (token == null) {
      final qp = Uri.base.queryParameters;
      token = qp['access_token'] ?? qp['code'];
    }

    if (token == null) return;

    // Keep the token for the submit step (we'll use it in the REST call)
    setState(() {
      _accessToken = token;
    });
  }

  Future<void> _submitNewPassword() async {
    final newPassword = _passwordController.text.trim();
    if (newPassword.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password must be at least 6 characters')));
      return;
    }

    setState(() => _loading = true);
    try {
      // Use the Supabase Auth REST endpoint to update the user's password.
      // This requires the access token that was forwarded from the redirect.
      final token = _accessToken ?? widget.accessToken;
      if (token == null) throw Exception('No access token available');

      // Supabase project URL (same as used in main.dart)
      const supabaseUrl = 'https://cfprqgciucpwwszdtrjg.supabase.co';
      final uri = Uri.parse('$supabaseUrl/auth/v1/user');
      final resp = await http.patch(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'password': newPassword}),
      );

      if (resp.statusCode != 200) {
        throw Exception('Failed to update password (${resp.statusCode}): ${resp.body}');
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password updated — please sign in')));
        context.go('/login');
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reset password'), backgroundColor: Colors.teal),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('Enter a new password', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            TextField(controller: _passwordController, obscureText: true, decoration: const InputDecoration(labelText: 'New password', border: OutlineInputBorder())),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(onPressed: _loading ? null : _submitNewPassword, style: ElevatedButton.styleFrom(backgroundColor: Colors.teal), child: _loading ? const CircularProgressIndicator(color: Colors.white) : const Text('Set password')),
            ),
          ]),
        ),
      ),
    );
  }
}
