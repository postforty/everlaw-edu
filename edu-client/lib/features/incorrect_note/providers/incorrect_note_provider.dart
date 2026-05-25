import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/incorrect_note.dart';
import '../../../core/network/dio_provider.dart';

class IncorrectNoteNotifier extends StateNotifier<List<IncorrectNote>> {
  final Dio _dio;

  IncorrectNoteNotifier(this._dio) : super([]) {
    loadNotes();
  }

  Future<void> loadNotes() async {
    try {
      final response = await _dio.get('/progress/incorrect-notes');
      if (response.statusCode == 200) {
        final List<dynamic> decodedList = response.data;
        state = decodedList.map((item) => IncorrectNote.fromMap(item)).toList();
      }
    } catch (e) {
      // 에러 발생 시 처리 (현재는 로그 또는 무시)
    }
  }

  Future<void> addNote(IncorrectNote note) async {
    // API 서버에서 오답노트 추가 처리를 할 수도 있지만, 
    // 로컬 상태를 우선 업데이트하고 registerQuizResult 시 함께 서버로 전송됨
    final existingIndex = state.indexWhere((n) => n.quizId == note.quizId);
    if (existingIndex >= 0) {
      final newState = [...state];
      newState[existingIndex] = note;
      state = newState;
    } else {
      state = [note, ...state];
    }
  }

  Future<void> deleteNote(String id) async {
    state = state.where((note) => note.id != id).toList();
    // TODO: 서버에 삭제 요청 (필요한 경우)
  }

  Future<void> archiveByLawReference(String lawReference) async {
    state = state.map((note) {
      if (note.lawReference == lawReference) {
        return note.copyWith(isArchived: true);
      }
      return note;
    }).toList();
  }

  /// returns true if mastery achieved (consecutive reached 3)
  Future<bool> registerQuizResult(String lawReference, bool isCorrect) async {
    try {
      final response = await _dio.post(
        '/progress/quiz-result',
        data: {
          'lawReference': lawReference,
          'isCorrect': isCorrect,
        },
      );

      if (response.statusCode == 200) {
        final data = response.data;
        final masteryAchieved = data['masteryAchieved'] ?? false;
        
        if (masteryAchieved) {
          await archiveByLawReference(lawReference);
        }
        return masteryAchieved;
      }
    } catch (e) {
      return false;
    }
    return false;
  }
}

final incorrectNoteProvider = StateNotifierProvider<IncorrectNoteNotifier, List<IncorrectNote>>((ref) {
  final dio = ref.watch(dioProvider);
  return IncorrectNoteNotifier(dio);
});
