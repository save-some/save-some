import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:save_some_ui/forms/signup.dart';

class SignInForm extends StatefulWidget {
  const SignInForm({super.key});

  @override
  State<SignInForm> createState() => _SignInFormState();
}

class _SignInFormState extends State<SignInForm> {
  final _controller = TextEditingController();
  bool _attempted = false; // only show empty-field error after a submit attempt

  final _darkBtn = ElevatedButton.styleFrom(
    backgroundColor: const Color.fromARGB(255, 48, 46, 46),
    foregroundColor: Colors.white,
    elevation: 0,
    shadowColor: Colors.transparent,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
  );

  final _lightBtn = ElevatedButton.styleFrom(
    backgroundColor: Colors.white,
    foregroundColor: Colors.black,
    elevation: 1,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
  );

  double _scaledWidth(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    return w > 500 ? w / 2 : w;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // TODO  Email magic-link
  Future<void> _submitEmail() async {
    setState(() => _attempted = true);
    final email = _controller.value.text.trim();
    if (email.isEmpty) return; // silently block — no red text

    try {
      await Supabase.instance.client.auth.signInWithOtp(
        email: email,
        emailRedirectTo: 'com.yourapp://login-callback', // ← change this
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Check your email for a magic link!')),
      );
    } on AuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  // Google SSO
  Future<void> _signInWithGoogle() async {
    try {
      await Supabase.instance.client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: 'com.yourapp://login-callback', // ← change this
      );
      // Navigation is handled by your auth state listener
    } on AuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  // GitHub SSO
  Future<void> _signInWithGitHub() async {
    try {
      await Supabase.instance.client.auth.signInWithOAuth(
        OAuthProvider.github,
        redirectTo: 'com.yourapp://login-callback', // ← change this
      );
    } on AuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  /* Reusable SSO Button
  Widget _ssoButton({
    required String assetPath,
    required VoidCallback onPressed,
  }) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: SizedBox(
        height: 50,
        width: 50,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 15),
          child: ElevatedButton(
            onPressed: onPressed,
            style: _lightBtn,
            child: SvgPicture.asset(
              assetPath,
              height: 25,
              width: 25,
              placeholderBuilder: (_) => const SizedBox(
                height: 22,
                width: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ),
        ),
      ),
    );
  }

  */

  Widget _ssoButton({
    required String assetPath,
    required VoidCallback onPressed,
  }) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: ElevatedButton(
        style: ButtonStyle(),
        onPressed: onPressed,
        child: SvgPicture.asset(
          assetPath,
          height: 30,
          width: 30,
          placeholderBuilder: (_) => const SizedBox(
            height: 25,
            width: 25,
            child: CircularProgressIndicator(strokeWidth: 3),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final email = _controller.value.text.trim();
    final showEmptyWarning = _attempted && email.isEmpty;

    return Scaffold(
      body: Center(
        child: Container(
          color: Colors.white,
          width: _scaledWidth(context),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo?
              Padding(
                padding: const EdgeInsets.fromLTRB(23, 0, 23, 4),
                child: SizedBox(
                  height: 200,
                  width: 200,
                  child: SvgPicture.asset(
                    'assets/wallet-logo.svg',
                    height: 200,
                    width: 200,
                    placeholderBuilder: (_) => const SizedBox(
                      height: 25,
                      width: 25,
                      child: CircularProgressIndicator(strokeWidth: 3),
                    ),
                  ),
                ),
              ),

              Padding(
                padding: const EdgeInsets.fromLTRB(23, 0, 23, 4),
                child: SizedBox(
                  height: 100,
                  width: 100,
                  child:  Text(
                    'Save\nSome',
                    
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
          
                      //height: 40, 
                      fontSize: 30,
                      color: Colors.black),
                  ),
                ),
              ),

              // Email field
              Padding(
                padding: const EdgeInsets.fromLTRB(23, 0, 23, 4),
                child: TextField(
                  controller: _controller,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    border: const OutlineInputBorder(),
                    labelText: 'enter your email ...',
                    // No errorText — validation is silent
                  ),
                ),
              ),

              // Subtle hint shown only after a failed submit attempt
              if (showEmptyWarning)
                const Padding(
                  padding: EdgeInsets.only(left: 23, bottom: 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Please enter your email before signing in.',
                      style: TextStyle(fontSize: 12, color: Colors.black54),
                    ),
                  ),
                ),

              // Sign-In button
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: SizedBox(
                  height: 50,
                  width: double.infinity,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 15),
                    child: ElevatedButton(
                      onPressed: _submitEmail,
                      style: _darkBtn,
                      child: const Text('sign in'),
                    ),
                  ),
                ),
              ),

              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 16),
                child: Text('OR, use a provider'),
              ),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                spacing: 5.0,
                children: [
                  _ssoButton(
                    assetPath: 'assets/google-logo.svg',
                    //label: 'sign in with google',
                    onPressed: _signInWithGoogle,
                  ),

                  //  GitHub
                  _ssoButton(
                    assetPath: 'assets/github-logo.svg',
                    // label: 'sign in with github',
                    onPressed: _signInWithGitHub,
                  ),

                  // TODO Microsoft (stub)
                  _ssoButton(
                    assetPath: 'assets/microsoft-logo.svg',
                    //label: 'sign in with microsoft',
                    onPressed: () {},
                  ),

                  // TODO Apple (stub)
                  _ssoButton(
                    assetPath: 'assets/apple-173-logo.svg',
                    // label: 'sign in with apple',
                    onPressed: () {},
                  ),
                ],
              ),

              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 16),
                child: Text('OR'),
              ),

              /* TODO Passkey (stub)
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: SizedBox(
                  height: 50,
                  width: double.infinity,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 15),
                    child: ElevatedButton(
                      onPressed: () {},
                      style: _lightBtn,
                      child: const Text('sign in with a passkey'),
                    ),
                  ),
                ),
              ),
              

              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 16),
                child: Text('OR'),
              ),
              */
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: SizedBox(
                  height: 50,
                  width: double.infinity,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 15),
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute<void>(
                            builder: (context) => const SignUpForm(),
                          ),
                        );
                      },
                      style: _lightBtn,
                      child: const Text('sign up'),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
