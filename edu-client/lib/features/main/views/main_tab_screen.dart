import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../quiz/views/quiz_feed_screen.dart';
import 'dart:ui';
import '../../incorrect_note/views/incorrect_note_screen.dart';
import '../../approval/views/approval_queue_screen.dart';
import '../../../core/network/auth_provider.dart';
import '../../../core/widgets/responsive_layout.dart';
import '../../../core/theme/app_theme.dart';

class MainTabScreen extends ConsumerStatefulWidget {
  const MainTabScreen({super.key});

  @override
  ConsumerState<MainTabScreen> createState() => _MainTabScreenState();
}

class _MainTabScreenState extends ConsumerState<MainTabScreen> {
  int _currentIndex = 0;
  List<Widget> _getScreens(bool isAdmin) {
    if (isAdmin) {
      return [
        const QuizFeedScreen(),
        const IncorrectNoteScreen(),
        const ApprovalQueueScreen(),
      ];
    }
    return [
      const QuizFeedScreen(),
      const IncorrectNoteScreen(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final role = ref.watch(authServiceProvider).currentUserRole;
    final isAdmin = role == 'ADMIN';
    final screens = _getScreens(isAdmin);

    final scaffold = Scaffold(
      extendBody: true, // Required for floating glassmorphism
      body: IndexedStack(
        index: _currentIndex,
        children: screens,
      ),
      bottomNavigationBar: _buildFloatingNavBar(context, isAdmin),
    );

    return ResponsiveLayout(
      mobileBody: scaffold,
      webBody: Scaffold(
        backgroundColor: Colors.grey.shade200,
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: ClipRect(
              child: scaffold,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFloatingNavBar(BuildContext context, bool isAdmin) {
    final items = [
      const BottomNavigationBarItem(
        icon: Icon(Icons.psychology_rounded),
        label: '피드',
      ),
      const BottomNavigationBarItem(
        icon: Icon(Icons.menu_book_rounded),
        label: '오답 노트',
      ),
    ];

    if (isAdmin) {
      items.add(
        const BottomNavigationBarItem(
          icon: Icon(Icons.admin_panel_settings_rounded),
          label: '승인 대기열',
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(left: 24, right: 24, bottom: 24),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(30),
        boxShadow: AppShadows.floatingNav,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: BottomNavigationBar(
            currentIndex: _currentIndex,
            onTap: (index) => setState(() => _currentIndex = index),
            selectedItemColor: Theme.of(context).colorScheme.primary,
            unselectedItemColor: Colors.grey.shade500,
            backgroundColor: Colors.transparent,
            elevation: 0,
            showSelectedLabels: true,
            showUnselectedLabels: false,
            items: items,
          ),
        ),
      ),
    );
  }
}
