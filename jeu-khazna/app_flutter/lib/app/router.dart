import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/auth.dart';
import '../core/controller.dart';
import '../features/auth/auth_screen.dart';
import '../features/auth/privacy_screen.dart';
import '../features/briefing/briefing_screen.dart';
import '../features/campaign/campaign_screen.dart';
import '../features/friends/friends_screen.dart';
import '../features/radar/radar_screen.dart';
import '../features/leaderboard/leaderboard_screen.dart';
import '../features/intro/intro_screen.dart';
import '../features/play/play_screen.dart';
import '../features/profile/profile_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/shell/main_shell.dart';
import '../features/tutorial/tutorial_screen.dart';

/// انتقال بلا تداخل: الشاشة القديمة تختفي أوّلاً ثم تظهر الجديدة على خلفية معتمة
/// (يصلح «الشبح» الذي كان يظهر عند تراكب شاشتين شبه شفافتين).
CustomTransitionPage<void> _fade(GoRouterState state, Widget child) => CustomTransitionPage<void>(
      key: state.pageKey,
      child: child,
      opaque: true,
      transitionDuration: const Duration(milliseconds: 260),
      reverseTransitionDuration: const Duration(milliseconds: 200),
      transitionsBuilder: (context, anim, sec, child) => ColoredBox(
        color: const Color(0xFF0A0C0E),
        child: FadeTransition(
          opacity: CurvedAnimation(parent: anim, curve: const Interval(.35, 1, curve: Curves.easeOut)),
          child: FadeTransition(
            opacity: ReverseAnimation(CurvedAnimation(parent: sec, curve: const Interval(0, .5))),
            child: child,
          ),
        ),
      ),
    );

final GoRouter appRouter = GoRouter(
  initialLocation: '/',
  refreshListenable: authService,
  // الحساب إجباري: كل الشاشات (عدا المقدّمة والدخول والخصوصية) تتطلّب تسجيل الدخول.
  redirect: (context, state) {
    const open = {'/', '/login', '/privacy'};
    final loc = state.matchedLocation;
    if (!authService.signedIn && !open.contains(loc)) return '/login';
    if (authService.signedIn && loc == '/login') return '/home';
    return null;
  },
  routes: [
    GoRoute(path: '/login', pageBuilder: (c, s) => _fade(s, const AuthScreen())),
    GoRoute(path: '/privacy', pageBuilder: (c, s) => _fade(s, const PrivacyScreen())),
    GoRoute(path: '/', pageBuilder: (c, s) => _fade(s, const IntroScreen())),
    GoRoute(path: '/home', pageBuilder: (c, s) => _fade(s, const MainShell())),
    GoRoute(path: '/tutorial', pageBuilder: (c, s) => _fade(s, const TutorialScreen())),
    GoRoute(path: '/briefing', pageBuilder: (c, s) => _fade(s, const BriefingScreen())),
    GoRoute(path: '/campaign', pageBuilder: (c, s) => _fade(s, const CampaignScreen())),
    GoRoute(path: '/leaderboard', pageBuilder: (c, s) => _fade(s, const LeaderboardScreen())),
    GoRoute(path: '/settings', pageBuilder: (c, s) => _fade(s, const SettingsScreen())),
    GoRoute(path: '/profile', pageBuilder: (c, s) => _fade(s, const ProfileScreen())),
    GoRoute(path: '/radar', pageBuilder: (c, s) => _fade(s, const RadarScreen())),
    GoRoute(path: '/friends', pageBuilder: (c, s) => _fade(s, const FriendsScreen())),
    GoRoute(
      path: '/play',
      pageBuilder: (c, s) {
        final controller = s.extra;
        if (controller is! GameController) return _fade(s, const MainShell());
        return _fade(s, PlayScreen(controller: controller));
      },
    ),
  ],
);
