import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:edu_client/main.dart';
import 'package:edu_client/core/providers/shared_preferences_provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('App WelcomeScreen basic render smoke test', (WidgetTester tester) async {
    dotenv.loadFromString(envString: 'API_BASE_URL=http://localhost:8080\nBASE_URL=http://localhost:8080');

    // SharedPreferences mock 초기 설정
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    // ProviderScope에 mock 주입하여 앱 실행
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
        child: const MyApp(),
      ),
    );

    // WelcomeScreen 로딩 중 앱 기본 타이틀과 설명 문구가 노출되는지 검증
    expect(find.text('EverLaw Edu'), findsOneWidget);
    expect(find.text('최신 법령 DB 기반 지능형 교육 및 컴플라이언스 솔루션'), findsOneWidget);
    expect(find.byIcon(Icons.gavel_rounded), findsOneWidget);

    // WelcomeScreen 내부의 Future.delayed 타이머들을 소진시키기 위해 충분한 가상 시간 흐름 부여
    await tester.pump(const Duration(seconds: 10));
  });
}
