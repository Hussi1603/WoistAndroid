import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';
import 'models/person.dart';
import 'screens/home_screen.dart';
import 'screens/onboarding_screen.dart';
import 'services/backend.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final options = DefaultFirebaseOptions.currentPlatform;
  if (options.apiKey == 'REPLACE_ME') {
    runApp(const _SetupMissingApp());
    return;
  }
  await Firebase.initializeApp(options: options);
  runApp(const WoIstApp());
}

ThemeData _theme(Brightness b) => ThemeData(
      useMaterial3: true,
      brightness: b,
      colorSchemeSeed: const Color(0xFF34C759),
    );

class WoIstApp extends StatelessWidget {
  const WoIstApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Wo ist?',
      debugShowCheckedModeBanner: false,
      theme: _theme(Brightness.light),
      darkTheme: _theme(Brightness.dark),
      home: const _Root(),
    );
  }
}

class _Root extends StatefulWidget {
  const _Root();

  @override
  State<_Root> createState() => _RootState();
}

class _RootState extends State<_Root> {
  Object? _signInError;
  bool _signingIn = false;

  Future<void> _signIn() async {
    if (_signingIn) return;
    _signingIn = true;
    setState(() => _signInError = null);
    try {
      await Backend.instance.ensureSignedIn();
    } catch (e) {
      if (mounted) setState(() => _signInError = e);
    } finally {
      _signingIn = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snap) {
        if (_signInError != null) {
          return _ErrorScreen(
            message: 'Anmeldung fehlgeschlagen:\n$_signInError\n\n'
                'Ist "Anonym" als Anmeldemethode in Firebase aktiviert?',
            onRetry: _signIn,
          );
        }
        final user = snap.data;
        if (user == null) {
          if (snap.connectionState == ConnectionState.active) {
            // Nicht angemeldet (erster Start oder Konto gelöscht).
            WidgetsBinding.instance.addPostFrameCallback((_) => _signIn());
          }
          return const _Loading();
        }
        return _ProfileGate(key: ValueKey(user.uid));
      },
    );
  }
}

class _ProfileGate extends StatefulWidget {
  const _ProfileGate({super.key});

  @override
  State<_ProfileGate> createState() => _ProfileGateState();
}

class _ProfileGateState extends State<_ProfileGate> {
  late final Stream<Profile?> _profile = Backend.instance.profileStream();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Profile?>(
      stream: _profile,
      builder: (context, ps) {
        if (ps.hasError) return _ErrorScreen(message: 'Fehler: ${ps.error}');
        if (ps.connectionState == ConnectionState.waiting) {
          return const _Loading();
        }
        final profile = ps.data;
        if (profile == null) return const OnboardingScreen();
        return HomeScreen(profile: profile);
      },
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: CircularProgressIndicator()));
}

class _ErrorScreen extends StatelessWidget {
  const _ErrorScreen({required this.message, this.onRetry});
  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.error_outline, size: 48),
              const SizedBox(height: 16),
              Text(message, textAlign: TextAlign.center),
              if (onRetry != null) ...[
                const SizedBox(height: 16),
                FilledButton(
                    onPressed: onRetry, child: const Text('Erneut versuchen')),
              ],
            ]),
          ),
        ),
      ),
    );
  }
}

class _SetupMissingApp extends StatelessWidget {
  const _SetupMissingApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: _theme(Brightness.light),
      home: const _ErrorScreen(
        message: 'Firebase ist noch nicht eingerichtet.\n\n'
            'Bitte "flutterfire configure" ausführen (siehe README.md) '
            'und die App neu bauen.',
      ),
    );
  }
}
