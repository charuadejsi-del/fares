import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'ui/home_screen.dart';
import 'ui/theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(const KhaznaApp());
}

class KhaznaApp extends StatelessWidget {
  const KhaznaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'الخزنة',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      // الواجهة كلها من اليمين إلى اليسار
      builder: (context, child) => Directionality(textDirection: TextDirection.rtl, child: child ?? const SizedBox()),
      home: const HomeScreen(),
    );
  }
}
