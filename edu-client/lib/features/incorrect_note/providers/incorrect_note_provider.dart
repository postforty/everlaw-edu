import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/incorrect_note.dart';
import '../../../core/providers/shared_preferences_provider.dart';

class IncorrectNoteNotifier extends StateNotifier<List<IncorrectNote>> {
  final SharedPreferences _prefs;
  static const String _storageKey = 'incorrect_notes_list';
  static const String _consecutiveKey = 'consecutive_correct_map';

  IncorrectNoteNotifier(this._prefs) : super([]) {
    _loadNotes();
  }

  void _loadNotes() {
    final String? notesJson = _prefs.getString(_storageKey);
    if (notesJson != null) {
      try {
        final List<dynamic> decodedList = json.decode(notesJson);
        state = decodedList.map((item) => IncorrectNote.fromMap(item)).toList();
      } catch (e) {
        state = [];
      }
    }
  }

  Future<void> _saveNotes() async {
    final String notesJson = json.encode(state.map((e) => e.toMap()).toList());
    await _prefs.setString(_storageKey, notesJson);
  }

  Future<void> addNote(IncorrectNote note) async {
    // If same quizId exists, overwrite it, else add new
    final existingIndex = state.indexWhere((n) => n.quizId == note.quizId);
    if (existingIndex >= 0) {
      final newState = [...state];
      newState[existingIndex] = note;
      state = newState;
    } else {
      state = [note, ...state];
    }
    await _saveNotes();
  }

  Future<void> deleteNote(String id) async {
    state = state.where((note) => note.id != id).toList();
    await _saveNotes();
  }

  Future<void> archiveByLawReference(String lawReference) async {
    state = state.map((note) {
      if (note.lawReference == lawReference) {
        return note.copyWith(isArchived: true);
      }
      return note;
    }).toList();
    await _saveNotes();
  }

  // Tracking consecutive correct answers
  Map<String, int> _getConsecutiveMap() {
    final String? mapJson = _prefs.getString(_consecutiveKey);
    if (mapJson != null) {
      return Map<String, int>.from(json.decode(mapJson));
    }
    return {};
  }

  Future<void> _saveConsecutiveMap(Map<String, int> map) async {
    await _prefs.setString(_consecutiveKey, json.encode(map));
  }

  /// returns true if mastery achieved (consecutive reached 3)
  Future<bool> registerQuizResult(String lawReference, bool isCorrect) async {
    final map = _getConsecutiveMap();
    if (isCorrect) {
      map[lawReference] = (map[lawReference] ?? 0) + 1;
      await _saveConsecutiveMap(map);
      if (map[lawReference]! >= 3) {
        // Mastery achieved
        await archiveByLawReference(lawReference);
        // Reset counter after mastery
        map[lawReference] = 0;
        await _saveConsecutiveMap(map);
        return true; 
      }
    } else {
      // Reset on incorrect
      map[lawReference] = 0;
      await _saveConsecutiveMap(map);
    }
    return false;
  }

  /// 특정 법령 조항에 대한 현재까지의 연속 정답 횟수를 안전하게 조회하는 퍼블릭 API
  int getConsecutiveCorrectCount(String lawReference) {
    final map = _getConsecutiveMap();
    return map[lawReference] ?? 0;
  }
}

final incorrectNoteProvider = StateNotifierProvider<IncorrectNoteNotifier, List<IncorrectNote>>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return IncorrectNoteNotifier(prefs);
});
