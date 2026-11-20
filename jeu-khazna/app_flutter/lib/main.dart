import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/router.dart';
import 'app/theme.dart';
import 'core/auth.dart';
import 'core/services.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    systemNavigationBarColor: K.bg,
  ));
  final prefs = await SharedPreferences.getInstance();
  await authService.init(prefs);
  runApp(ProviderScope(
    overrides: [prefsProvider.overrideWithValue(prefs)],
    child: const KhaznaApp(),
  ));
}

class KhaznaApp extends ConsumerStatefulWidget {
  const KhaznaApp({super.key});

  @override
  ConsumerState<KhaznaApp> createState() => _KhaznaAppState();
}

class _KhaznaAppState extends ConsumerState<KhaznaApp> {
  late final AppLifecycleListener _life;

  @override
  void initState() {
    super.initState();
    _life = AppLifecycleListener(
      onHide: () => ref.read(audioProvider).pauseForBackground(),
      onShow: () => ref.read(audioProvider).syncMusic(),
    );
  }

  @override
  void dispose() {
    _life.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'الخزنة',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      routerConfig: appRouter,
      builder: (context, child) {
        final app = Directionality(textDirection: TextDirection.rtl, child: child ?? const SizedBox());
        // على الحاسوب: نعرض اللعبة في إطار بعرض هاتف وسط النافذة
        return LayoutBuilder(builder: (context, box) {
          if (box.maxWidth <= 700) return app;
          return ColoredBox(
            color: const Color(0xFF010302),
            child: Center(
              child: Container(
                width: 540,
                decoration: BoxDecoration(
                  border: Border.symmetric(vertical: BorderSide(color: K.neon.withAlpha(60))),
                  boxShadow: K.glow(K.neon, 40, 40),
                ),
                child: MediaQuery(
                  data: MediaQuery.of(context).copyWith(size: Size(540, box.maxHeight)),
                  child: app,
                ),
              ),
            ),
          );
        });
      },
    );
  }
}
