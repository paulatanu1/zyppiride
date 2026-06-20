import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../core/utils/app_logger.dart';

// ============================================
// AUTH SERVICE PROVIDER
// ============================================
final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService(
    auth: FirebaseAuth.instance,
    firestore: FirebaseFirestore.instance,
  );
});

// ============================================
// PHONE AUTH STATE
// ============================================
enum PhoneAuthStatus {
  initial,
  codeSent,
  verifying,
  verified,
  error,
}

class PhoneAuthState {
  final PhoneAuthStatus status;
  final String? verificationId;
  final int? resendToken;
  final String? errorMessage;
  final bool isLoading;

  const PhoneAuthState({
    this.status = PhoneAuthStatus.initial,
    this.verificationId,
    this.resendToken,
    this.errorMessage,
    this.isLoading = false,
  });

  PhoneAuthState copyWith({
    PhoneAuthStatus? status,
    String? verificationId,
    int? resendToken,
    String? errorMessage,
    bool? isLoading,
  }) {
    return PhoneAuthState(
      status: status ?? this.status,
      verificationId: verificationId ?? this.verificationId,
      resendToken: resendToken ?? this.resendToken,
      errorMessage: errorMessage,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

// ============================================
// PHONE AUTH NOTIFIER
// ============================================
class PhoneAuthNotifier extends StateNotifier<PhoneAuthState> {
  final AuthService _authService;

  PhoneAuthNotifier(this._authService) : super(const PhoneAuthState());

  Future<void> sendOtp(String phoneNumber) async {
    state = state.copyWith(
      status: PhoneAuthStatus.initial,
      isLoading: true,
      errorMessage: null,
    );

    try {
      await _authService.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        onCodeSent: (verificationId, resendToken) {
          state = state.copyWith(
            status: PhoneAuthStatus.codeSent,
            verificationId: verificationId,
            resendToken: resendToken,
            isLoading: false,
          );
        },
        onVerificationCompleted: (credential) async {
          state = state.copyWith(
            status: PhoneAuthStatus.verifying,
            isLoading: true,
          );
          // Auto-verification on Android
          final result = await _authService.signInWithPhoneCredential(credential);
          if (result.isSuccess) {
            state = state.copyWith(
              status: PhoneAuthStatus.verified,
              isLoading: false,
            );
          } else {
            state = state.copyWith(
              status: PhoneAuthStatus.error,
              errorMessage: result.errorMessage,
              isLoading: false,
            );
          }
        },
        onVerificationFailed: (error) {
          state = state.copyWith(
            status: PhoneAuthStatus.error,
            errorMessage: _getPhoneAuthErrorMessage(error),
            isLoading: false,
          );
        },
        resendToken: state.resendToken,
      );
    } catch (e) {
      state = state.copyWith(
        status: PhoneAuthStatus.error,
        errorMessage: 'Failed to send OTP. Please try again.',
        isLoading: false,
      );
    }
  }

  Future<AuthResult> verifyOtp(String otp) async {
    if (state.verificationId == null) {
      return AuthResult.failure('Verification ID not found. Please request OTP again.');
    }

    state = state.copyWith(
      status: PhoneAuthStatus.verifying,
      isLoading: true,
      errorMessage: null,
    );

    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: state.verificationId!,
        smsCode: otp,
      );

      final result = await _authService.signInWithPhoneCredential(credential);

      if (result.isSuccess) {
        state = state.copyWith(
          status: PhoneAuthStatus.verified,
          isLoading: false,
        );
      } else {
        state = state.copyWith(
          status: PhoneAuthStatus.error,
          errorMessage: result.errorMessage,
          isLoading: false,
        );
      }

      return result;
    } catch (e) {
      state = state.copyWith(
        status: PhoneAuthStatus.error,
        errorMessage: 'Invalid OTP. Please try again.',
        isLoading: false,
      );
      return AuthResult.failure('Invalid OTP. Please try again.');
    }
  }

  void reset() {
    state = const PhoneAuthState();
  }

  String _getPhoneAuthErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-phone-number':
        return 'The phone number is invalid. Please enter a valid number.';
      case 'too-many-requests':
        return 'Too many requests. Please try again later.';
      case 'quota-exceeded':
        return 'SMS quota exceeded. Please try again later.';
      case 'operation-not-allowed':
        return 'Phone authentication is not enabled. Please contact support.';
      default:
        return e.message ?? 'Phone verification failed. Please try again.';
    }
  }
}

final phoneAuthNotifierProvider =
    StateNotifierProvider<PhoneAuthNotifier, PhoneAuthState>((ref) {
  final authService = ref.watch(authServiceProvider);
  return PhoneAuthNotifier(authService);
});

// ============================================
// AUTH RESULT
// ============================================
class AuthResult {
  final bool isSuccess;
  final User? user;
  final String? errorMessage;
  final bool isNewUser;

  const AuthResult._({
    required this.isSuccess,
    this.user,
    this.errorMessage,
    this.isNewUser = false,
  });

  factory AuthResult.success(User user, {bool isNewUser = false}) {
    return AuthResult._(
      isSuccess: true,
      user: user,
      isNewUser: isNewUser,
    );
  }

  factory AuthResult.failure(String message) {
    return AuthResult._(
      isSuccess: false,
      errorMessage: message,
    );
  }
}

// ============================================
// AUTH SERVICE
// ============================================
class AuthService {
  final FirebaseAuth auth;
  final FirebaseFirestore firestore;
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
  );

  AuthService({
    required this.auth,
    required this.firestore,
  });

  User? get currentUser => auth.currentUser;

  Stream<User?> get authStateChanges => auth.authStateChanges();

  // ============================================
  // EMAIL/PASSWORD AUTHENTICATION
  // ============================================
  Future<AuthResult> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );

      if (credential.user != null) {
        await firestore.collection('users').doc(credential.user!.uid).set(
          {'lastLoginAt': FieldValue.serverTimestamp()},
          SetOptions(merge: true),
        );
        await _logAnalyticsEvent('login', method: 'email');
        return AuthResult.success(credential.user!);
      }

      return AuthResult.failure('Login failed. Please try again.');
    } on FirebaseAuthException catch (e) {
      return AuthResult.failure(_getEmailAuthErrorMessage(e));
    } catch (e) {
      AppLogger.error('Email login error', tag: 'AuthService', error: e);
      return AuthResult.failure('An unexpected error occurred. Please try again.');
    }
  }

  Future<AuthResult> registerWithEmail({
    required String email,
    required String password,
    required String mobile,
  }) async {
    try {
      final existing = await firestore
          .collection('users')
          .where('mobile', isEqualTo: mobile.trim())
          .limit(1)
          .get();

      if (existing.docs.isNotEmpty) {
        return AuthResult.failure('This mobile number is already registered.');
      }

      final credential = await auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );

      if (credential.user != null) {
        // Update display name with mobile
        await credential.user!.updateProfile(displayName: mobile.trim());

        // Create user document in Firestore
        await _createUserDocument(
          uid: credential.user!.uid,
          email: email.trim(),
          mobile: mobile.trim(),
          authMethod: 'email',
        );

        await _logAnalyticsEvent('sign_up', method: 'email');
        return AuthResult.success(credential.user!, isNewUser: true);
      }

      return AuthResult.failure('Registration failed. Please try again.');
    } on FirebaseAuthException catch (e) {
      return AuthResult.failure(_getEmailAuthErrorMessage(e));
    } catch (e) {
      AppLogger.error('Email registration error', tag: 'AuthService', error: e);
      return AuthResult.failure('An unexpected error occurred. Please try again.');
    }
  }

  // ============================================
  // GOOGLE SIGN-IN
  // ============================================
  Future<AuthResult> signInWithGoogle() async {
    try {
      // Trigger the authentication flow
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        // User cancelled the sign-in
        return AuthResult.failure('Google sign-in was cancelled.');
      }

      // Obtain the auth details from the request
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      // Create a new credential
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign in to Firebase with the Google credential
      final userCredential = await auth.signInWithCredential(credential);

      if (userCredential.user != null) {
        final isNewUser = userCredential.additionalUserInfo?.isNewUser ?? false;

        // Create or update user document
        await _createOrUpdateUserDocument(
          uid: userCredential.user!.uid,
          email: userCredential.user!.email,
          displayName: userCredential.user!.displayName,
          photoUrl: userCredential.user!.photoURL,
          authMethod: 'google',
          isNewUser: isNewUser,
        );

        await _logAnalyticsEvent(isNewUser ? 'sign_up' : 'login', method: 'google');
        return AuthResult.success(userCredential.user!, isNewUser: isNewUser);
      }

      return AuthResult.failure('Google sign-in failed. Please try again.');
    } on FirebaseAuthException catch (e) {
      AppLogger.error('Google sign-in Firebase error: ${e.code}', tag: 'AuthService', error: e.message);
      return AuthResult.failure(_getGoogleAuthErrorMessage(e));
    } catch (e) {
      AppLogger.error('Google sign-in error', tag: 'AuthService', error: e);
      return AuthResult.failure('Google sign-in failed. Please try again.');
    }
  }

  // ============================================
  // PHONE AUTHENTICATION
  // ============================================
  Future<void> verifyPhoneNumber({
    required String phoneNumber,
    required void Function(String verificationId, int? resendToken) onCodeSent,
    required void Function(PhoneAuthCredential credential) onVerificationCompleted,
    required void Function(FirebaseAuthException error) onVerificationFailed,
    int? resendToken,
  }) async {
    await auth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      verificationCompleted: onVerificationCompleted,
      verificationFailed: onVerificationFailed,
      codeSent: onCodeSent,
      codeAutoRetrievalTimeout: (verificationId) {
        AppLogger.debug('Auto retrieval timeout for: $verificationId', tag: 'PhoneAuth');
      },
      forceResendingToken: resendToken,
      timeout: const Duration(seconds: 60),
    );
  }

  Future<AuthResult> signInWithPhoneCredential(PhoneAuthCredential credential) async {
    try {
      final userCredential = await auth.signInWithCredential(credential);

      if (userCredential.user != null) {
        final isNewUser = userCredential.additionalUserInfo?.isNewUser ?? false;

        // Create or update user document
        await _createOrUpdateUserDocument(
          uid: userCredential.user!.uid,
          phoneNumber: userCredential.user!.phoneNumber,
          authMethod: 'phone',
          isNewUser: isNewUser,
        );

        await _logAnalyticsEvent(isNewUser ? 'sign_up' : 'login', method: 'phone');
        return AuthResult.success(userCredential.user!, isNewUser: isNewUser);
      }

      return AuthResult.failure('Phone verification failed. Please try again.');
    } on FirebaseAuthException catch (e) {
      return AuthResult.failure(_getPhoneAuthErrorMessage(e));
    } catch (e) {
      AppLogger.error('Phone sign-in error', tag: 'AuthService', error: e);
      return AuthResult.failure('Phone verification failed. Please try again.');
    }
  }

  // ============================================
  // FORGOT PASSWORD
  // ============================================
  Future<({bool success, String? errorMessage})> sendPasswordResetEmail(String email) async {
    try {
      await auth.sendPasswordResetEmail(email: email.trim());
      return (success: true, errorMessage: null);
    } on FirebaseAuthException catch (e) {
      return (success: false, errorMessage: _getPasswordResetErrorMessage(e));
    } catch (e) {
      AppLogger.error('Password reset error', tag: 'AuthService', error: e);
      return (success: false, errorMessage: 'Failed to send reset email. Please try again.');
    }
  }

  String _getPasswordResetErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'No account found with this email address.';
      case 'invalid-email':
        return 'The email address is not valid.';
      case 'too-many-requests':
        return 'Too many requests. Please wait and try again.';
      default:
        return e.message ?? 'Failed to send reset email. Please try again.';
    }
  }

  // ============================================
  // EMAIL VERIFICATION
  // ============================================
  Future<AuthResult> sendEmailVerification() async {
    try {
      final user = auth.currentUser;
      if (user == null) {
        return AuthResult.failure('No user logged in.');
      }

      if (user.emailVerified) {
        return AuthResult.failure('Email is already verified.');
      }

      await user.sendEmailVerification();
      return AuthResult.success(user);
    } on FirebaseAuthException catch (e) {
      return AuthResult.failure(_getEmailVerificationErrorMessage(e));
    } catch (e) {
      AppLogger.error('Email verification error', tag: 'AuthService', error: e);
      return AuthResult.failure('Failed to send verification email. Please try again.');
    }
  }

  Future<bool> checkEmailVerified() async {
    try {
      final user = auth.currentUser;
      if (user == null) return false;

      // Reload user to get latest email verification status
      await user.reload();
      return auth.currentUser?.emailVerified ?? false;
    } catch (e) {
      AppLogger.error('Check email verified error', tag: 'AuthService', error: e);
      return false;
    }
  }

  bool get isEmailVerified => auth.currentUser?.emailVerified ?? false;

  String _getEmailVerificationErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'too-many-requests':
        return 'Too many requests. Please wait and try again.';
      default:
        return e.message ?? 'Failed to send verification email.';
    }
  }

  // ============================================
  // SIGN OUT
  // ============================================
  Future<void> signOut() async {
    try {
      // Sign out from Google if signed in
      if (await _googleSignIn.isSignedIn()) {
        await _googleSignIn.signOut();
      }
      // Sign out from Firebase
      await auth.signOut();
    } catch (e) {
      AppLogger.error('Sign out error', tag: 'AuthService', error: e);
      rethrow;
    }
  }

  // ============================================
  // HELPER METHODS
  // ============================================
  Future<void> _createUserDocument({
    required String uid,
    String? email,
    String? mobile,
    required String authMethod,
  }) async {
    await firestore.collection('users').doc(uid).set({
      'email': email,
      'mobile': mobile,
      'authMethod': authMethod,
      'verificationStatus': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
      'lastLoginAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _createOrUpdateUserDocument({
    required String uid,
    String? email,
    String? phoneNumber,
    String? displayName,
    String? photoUrl,
    required String authMethod,
    required bool isNewUser,
  }) async {
    final userDoc = firestore.collection('users').doc(uid);

    if (isNewUser) {
      // Create new user document
      await userDoc.set({
        'email': ?email,
        'mobile': ?phoneNumber,
        'fullName': ?displayName,
        'profileImageUrl': ?photoUrl,
        'authMethod': authMethod,
        'verificationStatus': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'lastLoginAt': FieldValue.serverTimestamp(),
        'isAdmin': false,
      });
    } else {
      // Update existing user document with any new info
      final updates = <String, dynamic>{
        'lastLoginAt': FieldValue.serverTimestamp(),
      };

      if (email != null) updates['email'] = email;
      if (displayName != null) updates['fullName'] = displayName;
      if (photoUrl != null) updates['profileImageUrl'] = photoUrl;

      await userDoc.set(updates, SetOptions(merge: true));
    }
  }

  Future<bool> checkUserHasRole(String uid) async {
    try {
      final doc = await firestore.collection('users').doc(uid).get();
      if (doc.exists) {
        final data = doc.data();
        return data?['role'] != null && data!['role'].toString().isNotEmpty;
      }
      return false;
    } catch (e) {
      AppLogger.error('Error checking user role', tag: 'AuthService', error: e);
      return false;
    }
  }

  /// Get the user's role from Firestore
  /// Returns the role string ('User', 'Driver', 'Vehicle Owner') or null if not set
  Future<String?> getUserRole(String uid) async {
    try {
      final doc = await firestore.collection('users').doc(uid).get();
      if (doc.exists) {
        final data = doc.data();
        final role = data?['role'];
        if (role != null && role.toString().isNotEmpty) {
          return role.toString();
        }
      }
      return null;
    } catch (e) {
      AppLogger.error('Error getting user role', tag: 'AuthService', error: e);
      return null;
    }
  }

  Future<void> _logAnalyticsEvent(String event, {required String method}) async {
    try {
      if (event == 'sign_up') {
        await FirebaseAnalytics.instance.logSignUp(signUpMethod: method);
      } else {
        await FirebaseAnalytics.instance.logLogin(loginMethod: method);
      }
    } catch (e) {
      AppLogger.warning('Analytics error', tag: 'AuthService');
    }
  }

  String _getEmailAuthErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'No account found with this email.';
      case 'wrong-password':
        return 'Incorrect password. Please try again.';
      case 'invalid-email':
        return 'The email address is not valid.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'weak-password':
        return 'The password is too weak. Please choose a stronger password.';
      case 'email-already-in-use':
        return 'An account already exists for this email address.';
      case 'network-request-failed':
        return 'Network error. Please check your internet connection.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait a moment and try again.';
      case 'invalid-credential':
        return 'Invalid email or password. Please check and try again.';
      default:
        return e.message ?? 'Authentication failed. Please try again.';
    }
  }

  String _getGoogleAuthErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'account-exists-with-different-credential':
        return 'An account already exists with this email using a different sign-in method.';
      case 'invalid-credential':
        return 'The Google credential is invalid. Please try again.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'network-request-failed':
        return 'Network error. Please check your internet connection.';
      default:
        return e.message ?? 'Google sign-in failed. Please try again.';
    }
  }

  String _getPhoneAuthErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-verification-code':
        return 'Invalid OTP. Please check and try again.';
      case 'invalid-verification-id':
        return 'Verification expired. Please request a new OTP.';
      case 'session-expired':
        return 'OTP has expired. Please request a new one.';
      case 'credential-already-in-use':
        return 'This phone number is already linked to another account.';
      default:
        return e.message ?? 'Phone verification failed. Please try again.';
    }
  }
}
