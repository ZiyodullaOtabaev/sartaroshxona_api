import 'package:firebase_auth/firebase_auth.dart';

class PhoneAuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  FirebaseAuth get auth => _auth;

  /// Telefon raqamiga 6 xonali SMS kod yuborish
  Future<void> sendOtp({
    required String phoneNumber,
    required Function(String verificationId, int? resendToken) onCodeSent,
    required Function(PhoneAuthCredential credential) onAutoVerify,
    required Function(String errorMessage) onError,
    int? forceResendingToken,
  }) async {
    try {
      final formattedPhone = formatPhoneNumber(phoneNumber);

      await _auth.verifyPhoneNumber(
        phoneNumber: formattedPhone,
        timeout: const Duration(seconds: 60),
        forceResendingToken: forceResendingToken,
        verificationCompleted: (PhoneAuthCredential credential) {
          // Android qurilmalarda SMS kod avtomatik o'qilganda
          onAutoVerify(credential);
        },
        verificationFailed: (FirebaseAuthException e) {
          String msg = "SMS kod yuborishda xatolik yuz berdi";
          if (e.code == 'invalid-phone-number') {
            msg = "Telefon raqami noto'g'ri kiritilgan";
          } else if (e.code == 'too-many-requests') {
            msg = "Juda ko'p urinish. Biroz kuting va qayta urinib ko'ring";
          } else if (e.code == 'quota-exceeded') {
            msg = "SMS limiti tugadi. Birozdan so'ng urinib ko'ring";
          } else if (e.message != null) {
            msg = e.message!;
          }
          onError(msg);
        },
        codeSent: (String verificationId, int? resendToken) {
          onCodeSent(verificationId, resendToken);
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          // Timeout bo'lganda
        },
      );
    } catch (e) {
      onError(e.toString());
    }
  }

  /// SMS kod orqali Firebase'ga kirish va User olish
  Future<User?> verifySmsCode({
    required String verificationId,
    required String smsCode,
  }) async {
    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: smsCode.trim(),
      );
      final userCredential = await _auth.signInWithCredential(credential);
      return userCredential.user;
    } catch (e) {
      rethrow;
    }
  }

  /// Telefon raqamini tozalash va standart xalqaro formatga keltirish (+998XXXXXXXXX)
  static String formatPhoneNumber(String raw) {
    String clean = raw.replaceAll(RegExp(r'[^0-9+]'), '');
    if (!clean.startsWith('+')) {
      if (clean.length == 9) {
        clean = '+998$clean';
      } else if (clean.length == 12 && clean.startsWith('998')) {
        clean = '+$clean';
      } else {
        clean = '+$clean';
      }
    }
    return clean;
  }
}
