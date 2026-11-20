import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../repositories/auth_repository.dart';

class AuthProvider extends ChangeNotifier {
  final AuthRepository repo;
  StreamSubscription<User?>? _sub;
  User? _user;
  bool _ready = false;

  AuthProvider({AuthRepository? repo}) : repo = repo ?? AuthRepository() {
    _sub = this.repo.authChanges().listen((u) {
      _user = u;
      _ready = true;
      notifyListeners();
    });
  }

  User? get user => _user;
  String? get uid => _user?.uid;
  bool get ready => _ready;
  bool get signedIn => _user != null;

  Future<void> register(String name, String email, String password) =>
      repo.register(name: name, email: email, password: password);
  Future<void> signIn(String email, String password) =>
      repo.signIn(email, password);
  Future<void> signInWithGoogle() => repo.signInWithGoogle();
  Future<void> sendPasswordReset(String email) => repo.sendPasswordReset(email);
  Future<void> signOut() => repo.signOut();

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
