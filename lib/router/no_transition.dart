import 'package:flutter/material.dart';

/// 페이지 전환 애니메이션 없이 교체하는 라우트
PageRouteBuilder<T> noTransition<T>(Widget page) {
  return PageRouteBuilder<T>(
    pageBuilder: (context, animation, secondaryAnimation) => page,
    transitionDuration: Duration.zero,
    reverseTransitionDuration: Duration.zero,
    opaque: true,
  );
}
