import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:local_auth/local_auth.dart';
import '../models/user_model.dart';

class AuthService {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  final _localAuth = LocalAuthentication();

  bool get isLoggedIn => _auth.currentUser != null;
  User? get currentUser => _auth.currentUser;

  // ── PHONE OTP ──

  /// Step 1: Send OTP to phone number (e.g. '+919876543210')
  Future<void> sendPhoneOTP({
    required String phoneNumber,
    required void Function(PhoneAuthCredential) onVerificationCompleted,
    required void Function(FirebaseAuthException) onVerificationFailed,
    required void Function(String, int?) onCodeSent,
    required void Function(String) onCodeAutoRetrievalTimeout,
  }) async {
    await _auth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      timeout: const Duration(seconds: 60),
      verificationCompleted: onVerificationCompleted,
      verificationFailed: onVerificationFailed,
      codeSent: onCodeSent,
      codeAutoRetrievalTimeout: onCodeAutoRetrievalTimeout,
    );
  }

  /// Step 2: Verify OTP code and sign in
  Future<({UserCredential credential, bool isNewUser})> verifyPhoneOTP(
    String verificationId,
    String smsCode,
  ) async {
    final credential = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: smsCode,
    );
    final result = await _auth.signInWithCredential(credential);
    final isNew = result.additionalUserInfo?.isNewUser ?? false;
    if (result.user != null) {
      await _ensureUserExists(result.user!, isNew: isNew);
      if (isNew) {
        await addWelcomeBonus(result.user!.uid);
      }
    }
    return (credential: result, isNewUser: isNew);
  }

  /// Auto-verification sign-in (Android only — called in onVerificationCompleted)
  Future<({UserCredential credential, bool isNewUser})> signInWithCredential(
    PhoneAuthCredential credential,
  ) async {
    final result = await _auth.signInWithCredential(credential);
    final isNew = result.additionalUserInfo?.isNewUser ?? false;
    if (result.user != null) {
      await _ensureUserExists(result.user!, isNew: isNew);
      if (isNew) await addWelcomeBonus(result.user!.uid);
    }
    return (credential: result, isNewUser: isNew);
  }

  Future<void> _ensureUserExists(User user, {bool isNew = false}) async {
    final ref = _firestore.collection('users').doc(user.uid);
    final existing = await ref.get();
    if (!existing.exists) {
      await ref.set(UserModel(
        uid: user.uid,
        email: user.email ?? '',
        phone: user.phoneNumber ?? '',
        createdAt: DateTime.now(),
        isNewUser: true,
      ).toMap());
    }
  }

  // ── PROFILE SETUP ──

  /// Save user name after OTP verification (new user onboarding step)
  Future<void> saveUserName({
    required String uid,
    required String name,
  }) async {
    // Input validation — prevent empty names and excessively long strings
    final trimmed = name.trim();
    if (trimmed.isEmpty) throw Exception('Name cannot be empty');
    if (trimmed.length < 2) throw Exception('Name must be at least 2 characters');
    if (trimmed.length > 50) throw Exception('Name is too long (max 50 characters)');

    await _firestore.collection('users').doc(uid).update({
      'name': trimmed,
      'isNewUser': false,
    });
    // Also update Firebase Auth display name
    await _auth.currentUser?.updateDisplayName(trimmed);
  }

  /// Full profile setup (name + gender + dob)
  Future<void> saveProfileSetup({
    required String uid,
    required String name,
    required String gender,
    DateTime? dob,
    String photoUrl = '',
  }) async {
    // Input validation
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) throw Exception('Name cannot be empty');
    if (trimmedName.length < 2) throw Exception('Name must be at least 2 characters');
    if (trimmedName.length > 50) throw Exception('Name is too long (max 50 characters)');

    const validGenders = ['male', 'female', 'other', 'prefer_not_to_say'];
    if (!validGenders.contains(gender.toLowerCase())) {
      throw Exception('Invalid gender value');
    }

    // Validate dob: must be in the past and not more than 120 years ago
    if (dob != null) {
      final now = DateTime.now();
      if (dob.isAfter(now)) throw Exception('Date of birth cannot be in the future');
      if (dob.isBefore(now.subtract(const Duration(days: 365 * 120)))) {
        throw Exception('Invalid date of birth');
      }
    }

    await _firestore.collection('users').doc(uid).update({
      'name': trimmedName,
      'gender': gender.toLowerCase(),
      if (dob != null) 'dob': dob,
      'photoUrl': photoUrl,
      'isNewUser': false,
    });
    await _auth.currentUser?.updateDisplayName(trimmedName);
  }

  // ── WELCOME BONUS ──

  /// Adds ₹150 wallet credit for new users. Safe to call once.
  Future<void> addWelcomeBonus(String uid) async {
    final userRef = _firestore.collection('users').doc(uid);
    final userSnap = await userRef.get();

    // Guard: only credit if not already credited
    if (userSnap.data()?['welcomeBonusCredited'] == true) return;

    await _firestore.runTransaction((txn) async {
      final snap = await txn.get(userRef);
      final currentBalance = (snap.data()?['walletBalance'] ?? 0).toDouble();
      txn.update(userRef, {
        'walletBalance': currentBalance + 150,
        'welcomeBonusCredited': true,
      });
      // Record transaction
      final txnRef = userRef.collection('transactions').doc();
      txn.set(txnRef, {
        'type': 'credit',
        'amount': 150,
        'reason': 'Welcome Bonus 🎉',
        'timestamp': DateTime.now(),
      });
    });
  }

  // ── BIOMETRIC AUTH ──

  Future<bool> isBiometricAvailable() async {
    try {
      final isAvailable = await _localAuth.canCheckBiometrics;
      final isDeviceSupported = await _localAuth.isDeviceSupported();
      return isAvailable && isDeviceSupported;
    } catch (_) {
      return false;
    }
  }

  Future<bool> authenticateWithBiometrics() async {
    try {
      return await _localAuth.authenticate(
        localizedReason: 'Authenticate to access Glamzo',
        options: const AuthenticationOptions(
          biometricOnly: false,
          stickyAuth: true,
        ),
      );
    } catch (_) {
      return false;
    }
  }

  // ── USER DATA ──

  Future<UserModel?> getCurrentUserModel() async {
    if (_auth.currentUser == null) return null;
    final doc = await _firestore
        .collection('users')
        .doc(_auth.currentUser!.uid)
        .get();
    if (!doc.exists) return null;
    return UserModel.fromMap(doc.data()!);
  }

  Future<void> updateUserProfile({
    required String uid,
    required String name,
    required String phone,
  }) async {
    await _firestore.collection('users').doc(uid).update({
      'name': name,
      'phone': phone,
    });
  }

  Future<void> updateUserPhone({
    required String uid,
    required String phone,
  }) async {
    await _firestore.collection('users').doc(uid).update({'phone': phone});
  }

  Future<void> saveUserToFirestore(User user, {String phone = ''}) async {
    final ref = _firestore.collection('users').doc(user.uid);
    final existing = await ref.get();
    if (!existing.exists) {
      await ref.set(UserModel(
        uid: user.uid,
        email: user.email ?? '',
        phone: phone,
        createdAt: DateTime.now(),
      ).toMap());
    }
  }

  Future<void> signOut() => _auth.signOut();
}
