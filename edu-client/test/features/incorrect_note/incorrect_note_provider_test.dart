import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:dio/dio.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:edu_client/features/incorrect_note/models/incorrect_note.dart';
import 'package:edu_client/features/incorrect_note/providers/incorrect_note_provider.dart';
import 'package:edu_client/core/database/database_helper.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class MockDio extends Mock implements Dio {}
class MockConnectivity extends Mock implements Connectivity {}
class MockDatabaseHelper extends Mock implements DatabaseHelper {}
class FakeIncorrectNote extends Fake implements IncorrectNote {}

void main() {
  late MockDio mockDio;
  late MockConnectivity mockConnectivity;
  late MockDatabaseHelper mockDatabaseHelper;
  late IncorrectNoteNotifier notifier;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    registerFallbackValue(FakeIncorrectNote());
  });

  setUp(() {
    mockDio = MockDio();
    mockConnectivity = MockConnectivity();
    mockDatabaseHelper = MockDatabaseHelper();
    
    when(() => mockConnectivity.onConnectivityChanged)
        .thenAnswer((_) => Stream.fromIterable([ConnectivityResult.none]));
    
    // Default mock behavior
    when(() => mockDatabaseHelper.getPendingDeleteIds()).thenAnswer((_) async => []);
  });

  IncorrectNoteNotifier createNotifier() {
    return IncorrectNoteNotifier(
      mockDio, 
      connectivity: mockConnectivity,
      dbHelper: mockDatabaseHelper,
    );
  }

  group('IncorrectNoteNotifier TDD', () {
    test('1. Zombie Data 방지 테스트: loadNotes() 호출 시 pendingDelete 항목 필터링', () async {
      // given
      final note1 = IncorrectNote(id: '1', quizId: 'q1', question: 'q1', options: [], answerIndex: 0, selectedIndex: 1, explanation: 'exp1', lawReference: 'law1', incorrectAt: '2023-01-01');
      final note2 = IncorrectNote(id: '2', quizId: 'q2', question: 'q2', options: [], answerIndex: 0, selectedIndex: 1, explanation: 'exp2', lawReference: 'law2', incorrectAt: '2023-01-01');
      
      final response = Response(
        requestOptions: RequestOptions(path: '/progress/incorrect-notes'),
        statusCode: 200,
        data: [note1.toMap(), note2.toMap()],
      );
      
      when(() => mockDio.get('/progress/incorrect-notes')).thenAnswer((_) async => response);
      when(() => mockDatabaseHelper.getPendingDeleteIds()).thenAnswer((_) async => ['1']); // '1' is pendingDelete

      // when
      notifier = createNotifier();
      await Future.delayed(Duration.zero); // wait for loadNotes() to complete

      // then
      expect(notifier.state.length, 1);
      expect(notifier.state.first.id, '2'); // '1' should be filtered out
    });

    test('2. 오프라인 삭제 트랜지션 테스트: 오프라인 시 삭제 요청하면 pendingDelete로 로컬 저장', () async {
      // given
      when(() => mockDio.delete(any())).thenThrow(DioException(
        requestOptions: RequestOptions(path: ''),
        type: DioExceptionType.connectionError,
      ));
      when(() => mockDatabaseHelper.insertNote(any())).thenAnswer((_) async => 1);
      
      notifier = createNotifier();
      notifier.state = [
        IncorrectNote(id: '1', quizId: 'q1', question: 'q1', options: [], answerIndex: 0, selectedIndex: 1, explanation: 'exp1', lawReference: 'law1', incorrectAt: '2023-01-01'),
      ];

      // when
      await notifier.deleteNote('1');

      // then
      verify(() => mockDatabaseHelper.insertNote(any())).called(1); // Saved to local DB as pendingDelete
      expect(notifier.state.isEmpty, true); // Removed from UI state
    });

    test('3. 백그라운드 동기화 정리 테스트: syncOutbox() 성공 시 로컬 DB에서 삭제', () async {
      // given
      when(() => mockDatabaseHelper.getPendingDeleteIds()).thenAnswer((_) async => ['1']);
      when(() => mockDio.delete('/progress/incorrect-notes/1')).thenAnswer((_) async => Response(
        requestOptions: RequestOptions(path: ''),
        statusCode: 204,
      ));
      when(() => mockDatabaseHelper.deleteNote('1')).thenAnswer((_) async => 1);

      notifier = createNotifier();

      // when
      await notifier.syncOutbox();

      // then
      verify(() => mockDio.delete('/progress/incorrect-notes/1')).called(1);
      verify(() => mockDatabaseHelper.deleteNote('1')).called(1);
    });
  });
}
