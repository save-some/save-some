import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';


import 'package:save_some_ui/screens/home.dart';
import 'package:save_some_ui/forms/signin.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: '.env');

  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'save-some',
      home: const AuthGate(),
    );
  }
}

/// Listens to Supabase auth state and routes accordingly.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  // Start by checking if a session already exists (e.g. returning user)
  bool _isSignedIn = Supabase.instance.client.auth.currentSession != null;

  @override
  void initState() {
    super.initState();
    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      final session = data.session;
      setState(() => _isSignedIn = session != null);
    });
  }

  @override
  Widget build(BuildContext context) {
    return _isSignedIn ? const HomeScreen() : const SignInForm();
  }
}

