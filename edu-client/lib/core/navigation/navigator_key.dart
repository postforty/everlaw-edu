import 'package:flutter/material.dart';

/// 전역 네비게이션을 위한 루트 키
/// 인터셉터 등 BuildContext가 없는 영역에서 화면 전환을 제어하기 위해 사용합니다.
final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();
