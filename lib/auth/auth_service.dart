
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService 
{
  final SupabaseClient _supabase = Supabase.instance.client;

  // sign up with confirmation
Future<void> registerUser({
  required String email,
  required String password,
}) async {
  final AuthResponse res = await _supabase.auth.signUp(
    email: email,
    password: password,
    // IMPORTANT: Include your deep link URL here if you want to redirect the user
    // to a specific part of your app after confirmation.
    // emailRedirectTo: 'myapp://login-callback', 
  );

  if (res.session != null) {
    // This case shouldn't happen if confirmation is ON, but good for completeness.
    // Handle the user being signed in immediately (e.g., if confirmation was temporarily off).
  } else if (res.user != null && res.session == null) {
    // 💡 This is the expected successful case: User created, email SENT, no session.
    // DO NOT attempt to update the 'profiles' table here.
    return; 
  } else {
    // Catch-all for unexpected failures (though usually AuthException handles errors)
    throw Exception('Registration failed to create user.');
  }
}

  // Sign In With Password and Email
  Future<AuthResponse> signInWithEmailPassword(String email, String password) async{
    return await _supabase.auth.signInWithPassword(email: email, password: password);
  }

  // Sign Up With Password and Email
  Future<AuthResponse> signUpWithEmailPassword (String email, String password) async {
    return await _supabase.auth.signUp(
      email: email,
      password: password,
    );
  }

  // Assuming _supabase is your SupabaseClient instance
// Assuming _supabase is your SupabaseClient instance
Future<void> registerUserWithProfile({
  required String email,
  required String password,
  required String username,
}) async {
  try {
    // 1. SIGN UP (Supabase Auth)
    final AuthResponse res = await _supabase.auth.signUp(
      email: email,
      password: password,
    );

    // 2. GET USER ID
    final String? userId = res.user?.id;

    if (userId == null) {
      // This happens if email confirmation is required and the session/user is empty,
      // or if sign-up failed (e.g., email already exists).
      throw Exception('Registration failed: User ID not returned.');
    }

    // 3. UPDATE PROFILE (Custom Table)
    // The database trigger has already created the basic row at this point.
    await _supabase
        .from('profile')
        .update({
          'username': username,
        })
        .eq('id', userId)
        .select();

  // Success!
  debugPrint('User registered and profile completed successfully.');
    
  } on AuthException catch (e) {
    // Catch specific Supabase Auth errors (e.g., "Email already registered")
    throw Exception('Authentication Error: ${e.message}');
  } catch (e) {
    // Catch any other error (e.g., RLS violation, database issue)
    throw Exception('Profile Update Error: $e');
  }
}

  Future<void> updateUserInfo (String username) async
  {
    final String? userId = _supabase.auth.currentUser?.id;

    await _supabase
        .from('profile')
        .update({
          'username': username,
        })
        .eq('id', userId!)
        .select();
  }

  // Sign Out
  Future<void> signOut() async{
     await _supabase.auth.signOut();
  }


  String? getCurrentUserEmail()
  {
    final session = _supabase.auth.currentSession;
    final user = session?.user;
    return user?.email;
  }

  /// Send a password reset email using Supabase Auth.
  ///
  /// Throws [AuthException] on Supabase auth errors, or other exceptions for unexpected failures.
  Future<void> resetPassword(String email) async {
    try {
      await _supabase.auth.resetPasswordForEmail(email);
    } on AuthException catch (e) {
      throw Exception('Authentication Error: ${e.message}');
    } catch (e) {
      throw Exception('Password reset failed: $e');
    }
  }

  
}