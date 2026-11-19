import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/controller.dart';
import '../features/briefing/briefing_screen.dart';
import '../features/campaign/campaign_screen.dart';
import '../features/home/home_screen.dart';
import '../features/intro/intro_screen.dart';
import '../features/play/play_screen.dart';
import '../features/profile/profile_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/tutorial/tutorial_screen.dart';

/// انتقال تلاشي + انزلاق خفيف بين الشاشات.
CustomTransitionPage<void> _fade(GoRouterState state, Widget child) => CustomTransitionPage<void>(
      key: state.pageKey,
      child: child,
      transitionDuration: const Duration(milliseconds: 420),
      transitionsBuilder: (context, anim, _, child) => FadeTransition(
        opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
        child: SlideTransition(
          position: Tween(begin: const Offset(0, 0.03), end: Offset.zero)
              .animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
          child: child,
        ),
      ),
    );

final GoRouter appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(path: '/', pageBuilder: (c, s) => _fade(s, const IntroScreen())),
    GoRoute(path: '/home', pageBuilder: (c, s) => _fade(s, const HomeScreen())),
    GoRoute(path: '/tutorial', pageBuilder: (c, s) => _fade(s, const TutorialScreen())),
    GoRoute(path: '/briefing', pageBuilder: (c, s) => _fade(s, const BriefingScreen())),
    GoRoute(path: '/campaign', pageBuilder: (c, s) => _fade(s, const CampaignScreen())),
    GoRoute(path: '/settings', pageBuilder: (c, s) => _fade(s, const SettingsScreen())),
    GoRoute(path: '/profile', pageBuilder: (c, s) => _fade(s, const ProfileScreen())),
    GoRoute(
      path: '/play',
      pageBuilder: (c, s) {
        final controller = s.extra;
        if (controller is! GameController) return _fade(s, const HomeScreen());
        return _fade(s, PlayScreen(controller: controller));
      },
    ),
  ],
);
