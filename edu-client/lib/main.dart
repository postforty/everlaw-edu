import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'features/main/views/main_tab_screen.dart';
import 'core/network/auth_provider.dart';

import 'package:shared_preferences/shared_preferences.dart';
import 'core/providers/shared_preferences_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
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
      title: 'EverLaw Edu',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1E3A8A), // Premium Deep Blue
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        fontFamily: 'Inter', // Sleek Typography
      ),
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

  @override
  void initState() {
    super.initState();
    _startInitialization();
  }

  Future<void> _startInitialization() async {
    // 1단계: 스플래시 대기 (1초)
    await Future.delayed(const Duration(milliseconds: 1000));
    if (!mounted) return;
    setState(() {
      _statusText = '학습 데이터베이스 연동 중...';
    });

    // 백그라운드 로그인 동기화
    await ref.read(authServiceProvider).authenticateDemoUser(DemoRole.learner);

    // 2단계: 추가 대기 후 메인 화면 자동 이동
    await Future.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;

    // 스플래시 화면이므로 뒤로 가기 불가능하게 pushReplacement 사용
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const MainTabScreen()),
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF1E3A8A), // Deep Blue
              Color(0xFF0F172A), // Slate Dark
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 40.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.gavel_rounded,
                      size: 80,
                      color: Colors.white,
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'EverLaw Edu',
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '최신 법령 DB 기반 지능형 교육 및 컴플라이언스 솔루션',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 15,
                        color: Colors.blueGrey[100],
                      ),
                    ),
                    const SizedBox(height: 48),
                    SizedBox(
                      height: 40,
                      width: 40,
                      child: CircularProgressIndicator(
                        strokeWidth: 3.5,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.blueGrey[100]!),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      _statusText,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.blueGrey[200],
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

}
