/// Firebase Authentication repository for arxivpanel.
///
/// Wraps [FirebaseAuth] and mirrors the signed-in user into the `users`
/// Firestore collection as an [AppUser]. Sign-in/sign-up failures surface
/// as user-friendly error strings (`null` means success).
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/models.dart';
import 'constants.dart';

/// Today's date as `yyyy-MM-dd`.
String _today() => DateTime.now().toIso8601String().substring(0, 10);

class AuthRepository {
  AuthRepository({FirebaseAuth? auth, FirebaseFirestore? firestore})
    : _auth = auth ?? FirebaseAuth.instance,
      _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  /// Streams the signed-in user's [AppUser] profile.
  ///
  /// Emits `null` when signed out or when no `users/{uid}` document exists.
  Stream<AppUser?> watchAuthUser() {
    return _auth
        .authStateChanges()
        .asyncMap((user) async {
          if (user == null) return null;
          final doc = await _firestore.collection('users').doc(user.uid).get();
          final data = doc.data();
          if (data == null) return null;
          return AppUser.fromJson(doc.id, data);
        })
        .handleError((Object e, StackTrace s) {
          debugPrint('[AuthRepository] watchAuthUser error: $e');
        });
  }

  /// Signs in with email and password.
  ///
  /// Returns `null` on success, otherwise a user-friendly error message.
  Future<String?> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      final user = credential.user;
      if (user != null) {
        // Self-heal: a previous sign-up may have created the Auth account
        // while the profile write failed (e.g. rules not published yet).
        // Create the missing users/{uid} doc so the account actually works.
        final doc = await _firestore.collection('users').doc(user.uid).get();
        if (!doc.exists) {
          final avatars = AppConstants.randomAvatars;
          await _firestore.collection('users').doc(user.uid).set({
            'username': (user.displayName?.isNotEmpty == true)
                ? user.displayName!
                : email.split('@').first,
            'email': user.email ?? email,
            'avatar': avatars[user.uid.hashCode.abs() % avatars.length],
            'bio': '',
            'joinedAt': _today(),
            'institution': null,
            'website': null,
            'isAdmin': false,
          });
        }
      }
      return null;
    } on FirebaseAuthException catch (e) {
      return _friendlySignInError(e.code);
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        return 'Signed in, but saving your profile was blocked. '
            'Publish the Firestore rules from firestore.rules, then try again.';
      }
      return 'Sign in failed (${e.code}). Please try again.';
    }
  }

  /// Creates an account, sets the display name, and writes the initial
  /// `users/{uid}` document.
  ///
  /// Returns `null` on success, otherwise a user-friendly error message.
  Future<String?> signUp({
    required String username,
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      final user = credential.user;
      if (user == null) {
        return 'Sign up failed. Please try again.';
      }
      await user.updateDisplayName(username);
      final avatars = AppConstants.randomAvatars;
      final avatar = avatars[user.uid.hashCode.abs() % avatars.length];
      await _firestore.collection('users').doc(user.uid).set({
        'username': username,
        'email': email,
        'avatar': avatar,
        'bio': '',
        'joinedAt': _today(),
        'institution': null,
        'website': null,
        'isAdmin': false,
      });
      return null;
    } on FirebaseAuthException catch (e) {
      return _friendlySignUpError(e.code);
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        return 'Account created, but saving your profile was blocked. '
            'Publish the Firestore rules from firestore.rules, then sign in — '
            'your profile will be created automatically.';
      }
      return 'Sign up failed (${e.code}). Please try again.';
    }
  }

  /// Signs the current user out.
  Future<void> signOut() => _auth.signOut();

  String _friendlySignInError(String code) {
    switch (code) {
      case 'user-not-found':
        return 'No account found for that email. Check the address or sign up.';
      case 'wrong-password':
        return 'Incorrect password. Please try again.';
      case 'invalid-email':
        return 'That email address is not valid.';
      case 'user-disabled':
        return 'This account has been disabled. Please contact support.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait a moment and try again.';
      case 'network-request-failed':
        return 'Network error. Check your connection and try again.';
      case 'invalid-credential':
        return 'Incorrect email or password. Please try again.';
      default:
        return 'Sign in failed ($code). Please try again.';
    }
  }

  String _friendlySignUpError(String code) {
    switch (code) {
      case 'email-already-in-use':
        return 'An account with that email already exists. Try signing in.';
      case 'weak-password':
        return 'That password is too weak. Please choose a stronger one.';
      case 'invalid-email':
        return 'That email address is not valid.';
      case 'operation-not-allowed':
        return 'Email/password sign-up is not enabled. In the Firebase console, go to Authentication → Sign-in method and enable Email/Password.';
      case 'network-request-failed':
        return 'Network error. Check your connection and try again.';
      default:
        return 'Sign up failed ($code). Please try again.';
    }
  }
}
