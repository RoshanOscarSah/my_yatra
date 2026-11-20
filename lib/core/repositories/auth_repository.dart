import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class AuthException implements Exception {
  final String message;
  final String code;
  AuthException(this.code, this.message);
  @override
  String toString() => message;
}

/// Firebase Auth wrapper (US-1.1 to US-1.4, US-1.6).
class AuthRepository {
  final FirebaseAuth _auth;
  final FirebaseFirestore _db;

  AuthRepository({FirebaseAuth? auth, FirebaseFirestore? db})
      : _auth = auth ?? FirebaseAuth.instance,
        _db = db ?? FirebaseFirestore.instance;

  Stream<User?> authChanges() => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;

  static String? validatePassword(String p) {
    if (p.length < 8) return 'Use at least 8 characters.';
    if (!RegExp(r'[A-Za-z]').hasMatch(p) || !RegExp(r'\d').hasMatch(p)) {
      return 'Use letters and at least one number.';
    }
    return null;
  }

  static String? validateEmail(String e) {
    final ok = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(e.trim());
    return ok ? null : 'Enter a valid email address.';
  }

  AuthException _map(FirebaseAuthException e) {
    switch (e.code) {
      case 'email-already-in-use':
        return AuthException(e.code,
            'This email is already registered. Please sign in instead.');
      case 'invalid-credential':
      case 'wrong-password':
      case 'user-not-found':
      case 'invalid-email':
        // Do not reveal which part was wrong (US-1.2).
        return AuthException(e.code, 'Email or password is incorrect.');
      case 'weak-password':
        return AuthException(e.code, 'Please choose a stronger password.');
      case 'too-many-requests':
        return AuthException(
            e.code, 'Too many attempts. Please wait a moment and try again.');
      case 'network-request-failed':
        return AuthException(e.code, 'No internet connection.');
      case 'requires-recent-login':
        return AuthException(e.code, 'Please sign in again to continue.');
      case 'popup-closed-by-user':
      case 'cancelled-popup-request':
        return AuthException(e.code, 'Sign-in was cancelled.');
      default:
        return AuthException(e.code, e.message ?? 'Something went wrong.');
    }
  }

  /// Creates the account and the users/{uid} document with the policy
  /// acceptance time in one step (US-1.1).
  Future<void> register({
    required String name,
    required String email,
    required String password,
  }) async {
    try {
      final cred = await _auth.createUserWithEmailAndPassword(
          email: email.trim(), password: password);
      await cred.user?.updateDisplayName(name.trim());
      await createProfile(cred.user!.uid, name.trim(), email.trim());
    } on FirebaseAuthException catch (e) {
      throw _map(e);
    }
  }

  Future<void> createProfile(String uid, String name, String email) {
    return _db.collection('users').doc(uid).set({
      'name': name,
      'email': email,
      'role': 'traveller',
      'policyAcceptedAt': FieldValue.serverTimestamp(),
      'gamificationOn': true,
      'onboardingComplete': false,
      'interests': <String>[],
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> signIn(String email, String password) async {
    try {
      await _auth.signInWithEmailAndPassword(
          email: email.trim(), password: password);
    } on FirebaseAuthException catch (e) {
      throw _map(e);
    }
  }

  Future<void> signInWithGoogle() async {
    try {
      final provider = GoogleAuthProvider();
      if (kIsWeb) {
        await _auth.signInWithPopup(provider);
      } else {
        await _auth.signInWithProvider(provider);
      }
    } on FirebaseAuthException catch (e) {
      throw _map(e);
    }
  }

  /// Firebase sends a single-use, expiring reset link (design decision for
  /// US-1.3, recorded in the workbook).
  Future<void> sendPasswordReset(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      // Don't reveal whether the email exists.
      if (e.code == 'user-not-found' || e.code == 'invalid-email') return;
      throw _map(e);
    }
  }

  Future<void> reauthenticate(String password) async {
    final user = _auth.currentUser;
    if (user == null || user.email == null) {
      throw AuthException('no-user', 'Please sign in again.');
    }
    try {
      await user.reauthenticateWithCredential(
          EmailAuthProvider.credential(email: user.email!, password: password));
    } on FirebaseAuthException catch (e) {
      throw _map(e);
    }
  }

  Future<void> deleteAuthUser() async {
    try {
      await _auth.currentUser?.delete();
    } on FirebaseAuthException catch (e) {
      throw _map(e);
    }
  }

  bool get usesPassword =>
      _auth.currentUser?.providerData.any((p) => p.providerId == 'password') ??
      false;

  Future<void> signOut() => _auth.signOut();
}
