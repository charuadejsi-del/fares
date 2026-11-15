import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config.dart';
import 'screens/home_shell.dart';
import 'screens/login_screen.dart';
import 'data/session.dart';
import 'theme.dart';
import 'utils.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Intl.defaultLocale = 'fr_FR';
  await initializeDateFormatting('fr_FR');
  await Future.wait([ThemeController.instance.load(), UiPrefs.instance.load()]);
  await Supabase.initialize(url: supabaseUrl, anonKey: supabaseKey);
  runApp(const AtelierApp());
}

class AtelierApp extends StatelessWidget {
  const AtelierApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeController.instance,
      builder: (context, mode, _) => MaterialApp(
        title: 'Atelier Broderie',
        debugShowCheckedModeBanner: false,
        locale: const Locale('fr', 'FR'),
        supportedLocales: const [Locale('fr', 'FR')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        theme: buildTheme(Brightness.light),
        darkTheme: buildTheme(Brightness.dark),
        themeMode: mode,
        home: const AuthGate(),
      ),
    );
  }
}

/// Affiche l'écran de connexion ou l'application selon la session.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = Supabase.instance.client.auth;
    return StreamBuilder<AuthState>(
      stream: auth.onAuthStateChange,
      builder: (context, _) {
        final user = auth.currentSession?.user;
        return user == null ? const LoginScreen() : SessionGate(key: ValueKey(user.id));
      },
    );
  }
}

/// Charge le compte (atelier, rôle, droits) avant d'ouvrir l'application.
class SessionGate extends StatefulWidget {
  const SessionGate({super.key});

  @override
  State<SessionGate> createState() => _SessionGateState();
}

class _SessionGateState extends State<SessionGate> {
  late Future<void> _f = session.load();

  @override
  Widget build(BuildContext context) => FutureBuilder<void>(
        future: _f,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          }
          final m = session.membre;
          if (snap.hasError || m == null || !m.actif) {
            return Scaffold(
              body: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(snap.hasError ? Icons.cloud_off_rounded : Icons.lock_outline_rounded, size: 48),
                    const SizedBox(height: 12),
                    Text(
                      snap.hasError ? errorMessage(snap.error!) : 'Ce compte est désactivé. Contactez l\'administrateur de l\'atelier.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    Wrap(spacing: 10, children: [
                      if (snap.hasError)
                        FilledButton.icon(
                          onPressed: () => setState(() => _f = session.load()),
                          icon: const Icon(Icons.refresh),
                          label: const Text('Réessayer'),
                        ),
                      OutlinedButton.icon(
                        onPressed: () async {
                          session.clear();
                          await Supabase.instance.client.auth.signOut();
                        },
                        icon: const Icon(Icons.logout),
                        label: const Text('Se déconnecter'),
                      ),
                    ]),
                  ]),
                ),
              ),
            );
          }
          return const HomeShell();
        },
      );
}
