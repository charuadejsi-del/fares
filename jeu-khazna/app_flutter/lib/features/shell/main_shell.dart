// الهيكل الرئيسي بعد الدخول: 4 تبويبات (المقرّ، الحملة، المتجر، ملفّي) مع شريط سفلي.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../widgets/spy_ui.dart';
import '../../widgets/ui_kit.dart';
import '../campaign/campaign_screen.dart';
import '../home/home_screen.dart';
import '../profile/profile_screen.dart';
import '../shop/shop_screen.dart';

class MainShell extends ConsumerWidget {
  const MainShell({super.key});

  static const _tabs = <Widget>[
    HomeScreen(),
    CampaignScreen(embedded: true),
    _ShopTab(),
    ProfileScreen(embedded: true),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tab = ref.watch(tabProvider);
    return PopScope(
      canPop: tab == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) ref.read(tabProvider.notifier).state = 0;
      },
      child: Scaffold(
        backgroundColor: K.bg,
        extendBody: true,
        bottomNavigationBar: const AppNavBar(),
        body: SpyBackground(
          image: tab == 0 ? 'assets/images/home_bg.jpg' : null,
          dim: tab == 0 ? .82 : .72,
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 74),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 260),
                switchInCurve: Curves.easeOutCubic,
                transitionBuilder: (child, a) => FadeTransition(
                  opacity: a,
                  child: SlideTransition(position: Tween(begin: const Offset(0, .02), end: Offset.zero).animate(a), child: child),
                ),
                child: KeyedSubtree(key: ValueKey(tab), child: _tabs[tab]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ShopTab extends StatelessWidget {
  const _ShopTab();

  @override
  Widget build(BuildContext context) => const Column(children: [
        Padding(
          padding: EdgeInsets.fromLTRB(20, 12, 20, 0),
          child: Row(children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('المتجر', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
              MonoLabel('SUPPLY DEPOT // التموين', size: 10),
            ]),
          ]),
        ),
        Expanded(child: ShopScreen()),
      ]);
}
