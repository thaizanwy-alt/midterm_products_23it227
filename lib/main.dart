import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';
import 'screens/login_screen.dart';
import 'screens/product_list_screen.dart';
import 'services/auth_service.dart';
import 'services/product_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    runApp(
      ProductsApp(
        auth: AuthService(FirebaseAuth.instance),
        products: ProductService(FirebaseFirestore.instance),
      ),
    );
  } catch (error) {
    debugPrint('Firebase initialization failed: $error');
    runApp(const ProductsApp());
  }
}

class ProductsApp extends StatelessWidget {
  const ProductsApp({super.key, this.auth, this.products});

  final AuthService? auth;
  final ProductService? products;

  @override
  Widget build(BuildContext context) {
    const background = Color(0xfff4f7f6);
    const ink = Color(0xff183029);
    const primary = Color(0xff176552);
    final colors = ColorScheme.fromSeed(seedColor: primary).copyWith(
      primary: primary,
      secondaryContainer: const Color(0xffe4eee9),
      surfaceContainerLow: const Color(0xffedf3f0),
      outline: const Color(0xff809589),
      outlineVariant: const Color(0xffd5e1da),
      onSurface: ink,
      surface: Colors.white,
    );
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(10),
    );
    final text = ThemeData.light().textTheme.apply(
      bodyColor: ink,
      displayColor: ink,
    );
    return MaterialApp(
      title: 'Kho sản phẩm',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: colors,
        scaffoldBackgroundColor: background,
        dialogTheme: const DialogThemeData(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
        ),
        textTheme: text.copyWith(
          headlineSmall: text.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
          titleLarge: text.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          titleMedium: text.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: ink,
          scrolledUnderElevation: 0,
          shape: Border(bottom: BorderSide(color: Color(0xffd5e1da))),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: colors.outline),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            shape: shape,
            minimumSize: const Size(48, 48),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            shape: shape,
            minimumSize: const Size(48, 48),
          ),
        ),
      ),
      home: auth == null || products == null
          ? const Scaffold(
              body: Center(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Text(
                    'Không khởi tạo được Firebase. Kiểm tra cấu hình và mở lại ứng dụng.',
                  ),
                ),
              ),
            )
          : _AuthGate(auth: auth!, products: products!),
    );
  }
}

class _AuthGate extends StatefulWidget {
  const _AuthGate({required this.auth, required this.products});

  final AuthService auth;
  final ProductService products;

  @override
  State<_AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<_AuthGate> {
  late final _authState = widget.auth.authState;

  @override
  Widget build(BuildContext context) {
    // Auth khôi phục phiên khi mở lại ứng dụng. Chỉ admin được vào danh sách.
    return StreamBuilder<User?>(
      stream: _authState,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final user = snapshot.data;
        if (user != null && widget.auth.isAdmin(user)) {
          return ProductListScreen(auth: widget.auth, service: widget.products);
        }
        return LoginScreen(auth: widget.auth);
      },
    );
  }
}
