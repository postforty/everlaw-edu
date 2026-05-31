import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'features/main/views/main_tab_screen.dart';
import 'features/auth/views/login_screen.dart';
import 'core/network/auth_provider.dart';

import 'package:shared_preferences/shared_preferences.dart';
import 'core/providers/shared_preferences_provider.dart';
import 'core/theme/app_theme.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'core/navigation/navigator_key.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");

  final prefs = await SharedPreferences.getInstance();
  
  runApp(
    // Riverpod 상태 관리를 작동시키기 위한 글로벌 스코프 래핑
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: rootNavigatorKey,
      title: 'EverLaw Edu',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const WelcomeScreen(),
    );
  }
}

class WelcomeScreen extends ConsumerStatefulWidget {
  const WelcomeScreen({super.key});

  @override
  ConsumerState<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends ConsumerState<WelcomeScreen> {
  String _statusText = '최신 법률 데이터베이스 연동 중...';
  bool _isVisible = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() => setState(() => _isVisible = true));
    _startInitialization();
  }

  Future<void> _startInitialization() async {
    await Future.delayed(const Duration(milliseconds: 1000));
    if (!mounted) return;
    setState(() {
      _statusText = '학습 데이터베이스 연동 중...';
    });

    final isLoggedIn = await ref.read(authServiceProvider).checkAutoLogin();

    await Future.delayed(const Duration(milliseconds: 1200));
    if (!mounted) return;

    if (isLoggedIn) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const MainTabScreen()),
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.secondary,
      body: Stack(
        children: [
          // Background Glows
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 400,
              height: 400,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withValues(alpha: 0.15),
              ),
              // Use standard blur if ImageFilter is not imported, or we can use a simpler approach
              child: const DecoratedBox(
                decoration: BoxDecoration(
                  boxShadow: [BoxShadow(color: AppColors.primary, blurRadius: 200, spreadRadius: 50)],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -50,
            left: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.deepPurpleAccent.withValues(alpha: 0.1),
              ),
              child: const DecoratedBox(
                decoration: BoxDecoration(
                  boxShadow: [BoxShadow(color: Colors.deepPurpleAccent, blurRadius: 150, spreadRadius: 20)],
                ),
              ),
            ),
          ),
          // Main Content
          SafeArea(
            child: Center(
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 1200),
                opacity: _isVisible ? 1.0 : 0.0,
                curve: Curves.easeOutCubic,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // App Logo
                    Image.asset(
                      'assets/images/logo.png',
                      height: 190,
                      fit: BoxFit.contain,
                    ),
                    const SizedBox(height: 50),
                    // Typography
                    Text(
                      'EverLaw Edu',
                      style: TextStyle(
                        fontFamily: 'Outfit', // Or fallback to standard
                        fontSize: 34,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '차세대 지능형 법률 교육 플랫폼',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w400,
                        color: Colors.white.withValues(alpha: 0.6),
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 70),
                    // Elegant Loading Indicator
                    SizedBox(
                      width: 160,
                      child: Column(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: LinearProgressIndicator(
                              backgroundColor: Colors.white.withValues(alpha: 0.1),
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white.withValues(alpha: 0.7)),
                              minHeight: 3,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _statusText,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withValues(alpha: 0.5),
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
