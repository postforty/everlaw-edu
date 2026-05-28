import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../models/incorrect_note.dart';
import '../../../core/network/dio_provider.dart';
import '../../../core/database/database_helper.dart';

class IncorrectNoteNotifier extends StateNotifier<List<IncorrectNote>> {
  final Dio _dio;
  final Connectivity _connectivity;
  final DatabaseHelper _dbHelper;
  StreamSubscription? _connectivitySubscription;

  IncorrectNoteNotifier(
    this._dio, {
    Connectivity? connectivity,
    DatabaseHelper? dbHelper,
  })  : _connectivity = connectivity ?? Connectivity(),
        _dbHelper = dbHelper ?? DatabaseHelper.instance,
        super([]) {
    loadNotes();
    _initConnectivityListener();
  }

  void _initConnectivityListener() {
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen((result) {
      if (result != ConnectivityResult.none) {
        syncOutbox();
      }
    });
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    super.dispose();
  }

  Future<void> loadNotes() async {
    try {
      final response = await _dio.get('/progress/incorrect-notes');
      if (response.statusCode == 200) {
        final List<dynamic> decodedList = response.data;
        final serverNotes = decodedList.map((item) => IncorrectNote.fromMap(item)).toList();
        
        final localPendingDeletes = await _dbHelper.getPendingDeleteIds();
        
        state = serverNotes.where((n) => !localPendingDeletes.contains(n.id)).toList();
      }
    } catch (e) {
      // 에러 발생 시 처리
    }
  }

  Future<void> syncOutbox() async {
    final pendingDeletes = await _dbHelper.getPendingDeleteIds();
    for (final id in pendingDeletes) {
      try {
        final response = await _dio.delete('/progress/incorrect-notes/$id');
        if (response.statusCode == 204 || response.statusCode == 200) {
          await _dbHelper.deleteNote(id);
        }
      } catch (e) {
        // sync failed, will retry later
      }
    }
  }

  Future<void> addNote(IncorrectNote note) async {
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
    final noteToDelete = state.firstWhere(
      (note) => note.id == id, 
      orElse: () => IncorrectNote(id: id, quizId: '', question: '', options: [], answerIndex: 0, selectedIndex: 0, explanation: '', lawReference: '', incorrectAt: '')
    );
    if (noteToDelete.quizId.isEmpty) return; // Note not found in state

    // Optimistic UI update
    state = state.where((note) => note.id != id).toList();

    try {
      final response = await _dio.delete('/progress/incorrect-notes/$id');
      if (response.statusCode != 204 && response.statusCode != 200) {
        throw Exception('Delete failed');
      }
    } catch (e) {
      // Offline or network error: Save to local DB as pendingDelete
      final offlineNote = noteToDelete.copyWith(syncStatus: SyncStatus.pendingDelete);
      await _dbHelper.insertNote(offlineNote);
    }
  }

  Future<void> archiveByLawReference(String lawReference) async {
    state = state.map((note) {
      if (note.lawReference == lawReference) {
        return note.copyWith(isArchived: true);
      }
      return note;
    }).toList();
  }

  Future<bool> submitQuizResult(int quizId, int selectedIndex) async {
    try {
      final response = await _dio.post(
        '/progress/submit-quiz',
        data: {
          'quizId': quizId,
          'selectedIndex': selectedIndex,
        },
      );

      if (response.statusCode == 200) {
        final data = response.data;
        final isGraduated = data['isGraduated'] ?? false;
        
        if (isGraduated) {
          await loadNotes();
        } else if (data['isCorrect'] == false) {
           await loadNotes();
        }
        return isGraduated;
      }
    } catch (e) {
      return false;
    }
    return false;
  }

  Future<void> resetHistory() async {
    try {
      final response = await _dio.delete('/progress/reset');
      if (response.statusCode == 204 || response.statusCode == 200) {
        state = [];
        await _dbHelper.deleteAllNotes();
      }
    } catch (e) {
      // 에러 발생 시 처리
      throw Exception('이력 초기화에 실패했습니다.');
    }
  }
}

final incorrectNoteProvider = StateNotifierProvider<IncorrectNoteNotifier, List<IncorrectNote>>((ref) {
  final dio = ref.watch(dioProvider);
  return IncorrectNoteNotifier(dio);
});
