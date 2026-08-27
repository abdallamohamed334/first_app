import 'package:flutter/material.dart';

class PageTransition {
  // ============ SLIDE RIGHT TO LEFT ============
  static Route<T> slideRightToLeft<T>(Widget page) {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const begin = Offset(1.0, 0.0);
        const end = Offset.zero;
        const curve = Curves.easeInOutCubic;

        var tween =
            Tween(begin: begin, end: end).chain(CurveTween(curve: curve));

        return SlideTransition(
          position: animation.drive(tween),
          child: child,
        );
      },
      transitionDuration: const Duration(milliseconds: 400),
    );
  }

  // ============ SLIDE LEFT TO RIGHT ============
  static Route<T> slideLeftToRight<T>(Widget page) {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const begin = Offset(-1.0, 0.0);
        const end = Offset.zero;
        const curve = Curves.easeInOutCubic;

        var tween =
            Tween(begin: begin, end: end).chain(CurveTween(curve: curve));

        return SlideTransition(
          position: animation.drive(tween),
          child: child,
        );
      },
      transitionDuration: const Duration(milliseconds: 400),
    );
  }

  // ============ SLIDE BOTTOM TO TOP ============
  static Route<T> slideBottomToTop<T>(Widget page) {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const begin = Offset(0.0, 1.0);
        const end = Offset.zero;
        const curve = Curves.easeOutCubic;

        var tween =
            Tween(begin: begin, end: end).chain(CurveTween(curve: curve));

        return SlideTransition(
          position: animation.drive(tween),
          child: child,
        );
      },
      transitionDuration: const Duration(milliseconds: 500),
    );
  }

  // ============ FADE ============
  static Route<T> fade<T>(Widget page) {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: animation.drive(
            Tween(begin: 0.0, end: 1.0).chain(
              CurveTween(curve: Curves.easeInOut),
            ),
          ),
          child: child,
        );
      },
      transitionDuration: const Duration(milliseconds: 400),
    );
  }

  // ============ SCALE + FADE ============
  static Route<T> scaleFade<T>(Widget page) {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const curve = Curves.easeOutCubic;

        var scaleTween =
            Tween(begin: 0.9, end: 1.0).chain(CurveTween(curve: curve));

        var fadeTween =
            Tween(begin: 0.0, end: 1.0).chain(CurveTween(curve: curve));

        return FadeTransition(
          opacity: animation.drive(fadeTween),
          child: ScaleTransition(
            scale: animation.drive(scaleTween),
            child: child,
          ),
        );
      },
      transitionDuration: const Duration(milliseconds: 400),
    );
  }

  // ============ ROTATE + FADE ============
  static Route<T> rotateFade<T>(Widget page) {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const curve = Curves.easeOutCubic;

        var rotateTween =
            Tween(begin: -0.1, end: 0.0).chain(CurveTween(curve: curve));

        var fadeTween =
            Tween(begin: 0.0, end: 1.0).chain(CurveTween(curve: curve));

        return FadeTransition(
          opacity: animation.drive(fadeTween),
          child: RotationTransition(
            turns: animation.drive(rotateTween),
            child: child,
          ),
        );
      },
      transitionDuration: const Duration(milliseconds: 450),
    );
  }

  // ============ ZOOM ============
  static Route<T> zoom<T>(Widget page) {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const curve = Curves.easeOutCubic;

        var scaleTween =
            Tween(begin: 0.0, end: 1.0).chain(CurveTween(curve: curve));

        return ScaleTransition(
          scale: animation.drive(scaleTween),
          child: child,
        );
      },
      transitionDuration: const Duration(milliseconds: 500),
    );
  }

  // ============ CUSTOM WITH DELAY ============
  static Route<T> customWithDelay<T>(Widget page, {int delayMs = 200}) {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final delayedAnimation = CurvedAnimation(
          parent: animation,
          curve: Interval(
            delayMs / 1000.0,
            1.0,
            curve: Curves.easeOutCubic,
          ),
        );

        return FadeTransition(
          opacity: delayedAnimation.drive(
            Tween(begin: 0.0, end: 1.0),
          ),
          child: SlideTransition(
            position: delayedAnimation.drive(
              Tween(begin: const Offset(0.0, 0.2), end: Offset.zero),
            ),
            child: child,
          ),
        );
      },
      transitionDuration: const Duration(milliseconds: 600),
    );
  }
}

// ============ EXTENSION FOR EASY USE ============
extension PageTransitionExtension on BuildContext {
  void pushWithSlideRight(Widget page) {
    Navigator.push(this, PageTransition.slideRightToLeft(page));
  }

  void pushWithSlideLeft(Widget page) {
    Navigator.push(this, PageTransition.slideLeftToRight(page));
  }

  void pushWithSlideUp(Widget page) {
    Navigator.push(this, PageTransition.slideBottomToTop(page));
  }

  void pushWithFade(Widget page) {
    Navigator.push(this, PageTransition.fade(page));
  }

  void pushWithScaleFade(Widget page) {
    Navigator.push(this, PageTransition.scaleFade(page));
  }

  void pushWithZoom(Widget page) {
    Navigator.push(this, PageTransition.zoom(page));
  }

  void pushReplacementWithFade(Widget page) {
    Navigator.pushReplacement(this, PageTransition.fade(page));
  }

  void pushReplacementWithSlideRight(Widget page) {
    Navigator.pushReplacement(this, PageTransition.slideRightToLeft(page));
  }
}
