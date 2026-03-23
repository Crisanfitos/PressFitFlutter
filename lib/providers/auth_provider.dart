import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthProvider extends ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;

  User? _user;
  bool _loading = true;

  User? get user => _user;
  bool get isAuthenticated => _user != null;
  bool get loading => _loading;

  AuthProvider() {
    _init();
  }

  void _init() {
    _user = _supabase.auth.currentUser;
    _loading = false;
    notifyListeners();

    _supabase.auth.onAuthStateChange.listen((data) {
      _user = data.session?.user;
      _loading = false;
      notifyListeners();
    });
  }

  Future<void> signInWithEmail(String email, String password) async {
    _loading = true;
    notifyListeners();
    try {
      await _supabase.auth.signInWithPassword(email: email, password: password);
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> signUpWithEmail(String email, String password, String nombre) async {
    _loading = true;
    notifyListeners();
    try {
      final response = await _supabase.auth.signUp(
        email: email,
        password: password,
        data: {'nombre': nombre},
      );
      if (response.user != null) {
        await _supabase.from('usuarios').upsert({
          'id': response.user!.id,
          'email': email,
          'nombre': nombre,
        });
      }
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> signInWithGoogle() async {
    await _supabase.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: 'com.crisanfitos.pressfit://login-callback',
    );
  }

  Future<void> signOut() async {
    await _supabase.auth.signOut();
    _user = null;
    notifyListeners();
  }
}
