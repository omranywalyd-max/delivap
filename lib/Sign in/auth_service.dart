import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_application_1/Services/api_client.dart';
import 'package:flutter_application_1/Services/env_config.dart';
import 'package:flutter_application_1/user_local.dart';

class AuthService {
  static final _auth = FirebaseAuth.instance;
  static final _google = GoogleSignIn(
    serverClientId: EnvConfig.googleSignInServerClientId,
  );

  // --------------------------------------------------------------------------
  //  Email / Password — Sign Up
  // --------------------------------------------------------------------------
  static Future<UserCredential> signUpWithEmail({
    required String firstName,
    required String lastName,
    required String phone,
    required String email,
    required String password,
    required String gender,
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    await credential.user!.updateDisplayName('$firstName $lastName');

    await ApiClient.post('/api/users', {
      'uid': credential.user!.uid,
      'firstName': firstName,
      'lastName': lastName,
      'phone': phone,
      'email': email,
      'gender': gender,
    });

    UserLocal.data ??= {};
    UserLocal.data!['isActive'] = true;

    return credential;
  }

  // --------------------------------------------------------------------------
  //  Email / Password — Sign In
  // --------------------------------------------------------------------------
  static Future<UserCredential> signInWithEmail({
    required String email,
    required String password,
  }) async {
    return _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  // --------------------------------------------------------------------------
  //  Google Sign-In (Sign In + Sign Up ?? ??? ?????)
  // --------------------------------------------------------------------------
  static Future<UserCredential?> signInWithGoogle() async {
    try {
      await _google.signOut();
    } catch (e) {
    }

    try {
      final googleUser = await _google.signIn();
      if (googleUser == null) {
        return null;
      }
      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      final userCredential = await _auth.signInWithCredential(credential);
      final user = userCredential.user!;
      if (userCredential.additionalUserInfo?.isNewUser == true) {
        final nameParts = (user.displayName ?? '').split(' ');
        final firstName = nameParts.isNotEmpty ? nameParts.first : '';
        final lastName = nameParts.length > 1
            ? nameParts.sublist(1).join(' ')
            : '';
        await ApiClient.post('/api/users', {
          'uid': user.uid,
          'firstName': firstName,
          'lastName': lastName,
          'phone': user.phoneNumber ?? '',
          'email': user.email ?? '',
          'gender': '',
          'photoUrl': user.photoURL ?? '',
        });
        UserLocal.data ??= {};
        UserLocal.data!['isActive'] = true;
      }

      return userCredential;
    } on FirebaseAuthException catch (e) {
      rethrow;
    } catch (e) {
      rethrow;
    }
  }

  // --------------------------------------------------------------------------
  //  Reset Password
  // --------------------------------------------------------------------------
  static Future<void> sendPasswordReset(String email) async {
    await _auth.sendPasswordResetEmail(email: email.trim());
  }

  // --------------------------------------------------------------------------
  //  Re-authenticate (for delete account)
  // --------------------------------------------------------------------------
  static Future<AuthCredential?> reauthenticateWithGoogle() async {
    final googleUser = await _google.signIn();
    if (googleUser == null) return null;
    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );
    await _auth.currentUser?.reauthenticateWithCredential(credential);
    return credential;
  }

  static Future<void> reauthenticateWithEmail(String password) async {
    final user = _auth.currentUser;
    if (user?.email == null) throw Exception('?? ???? ???? ????????');
    final credential = EmailAuthProvider.credential(
      email: user!.email!,
      password: password,
    );
    await user.reauthenticateWithCredential(credential);
  }

  // --------------------------------------------------------------------------
  //  Sign Out
  // --------------------------------------------------------------------------
  static Future<void> signOut() async {
    try {
      final uid = _auth.currentUser?.uid;
      if (uid != null) {
        await ApiClient.post('/api/clear-token', {'uid': uid, 'role': 'user'}).catchError((_) {});
      }
    } catch (_) { /* ignored */ }
    await _google.signOut();
    await _auth.signOut();
  }

  // --------------------------------------------------------------------------
  //  ????? ????? ????????
  // --------------------------------------------------------------------------
  static String errorMessage(String code) {
    switch (code) {
      case 'email-already-in-use':
        return '?????? ?????????? ?????? ??????';
      case 'weak-password':
        return '???? ???? ????? (8 ???? ??? ?????)';
      case 'invalid-email':
        return '?????? ?????????? ??? ????';
      case 'user-not-found':
        return '?????? ?????????? ??? ????';
      case 'wrong-password':
        return '???? ???? ??? ?????';
      case 'invalid-credential':
        return '?????? ?? ???? ???? ??? ?????';
      case 'user-disabled':
        return '??? ?????? ?????';
      case 'too-many-requests':
        return '??????? ?????? ???? ??????';
      case 'network-request-failed':
        return '???? ?? ????? ????????';
      case 'sign_in_canceled':
        return '?? ????? ????? ??????';
      default:
        return '??? ???? ???? ??? ????';
    }
  }
}
