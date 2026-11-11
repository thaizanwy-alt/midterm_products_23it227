import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  AuthService(this._auth);

  // Cùng UID với firestore.rules. UID là định danh, mật khẩu ở Firebase Auth.
  static const adminUid = 'admin-23it227-midterm';

  final FirebaseAuth _auth;

  Stream<User?> get authState => _auth.authStateChanges();

  bool isAdmin(User user) => user.uid == adminUid;

  // Firebase xác minh email/mật khẩu, sau đó ứng dụng kiểm tra UID của admin.
  Future<void> signIn(String email, String password) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    final user = credential.user;
    if (user == null || !isAdmin(user)) {
      await signOut();
      throw FirebaseAuthException(code: 'admin-required');
    }
  }

  Future<void> signOut() => _auth.signOut();
}
