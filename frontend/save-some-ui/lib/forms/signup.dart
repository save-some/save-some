import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
// import 'package:supabase_flutter/supabase_flutter.dart';

class SignUpForm extends StatefulWidget {
  const SignUpForm({super.key});

  @override
  State<SignUpForm> createState() => _SignUpFormState();
}

class _SignUpFormState extends State<SignUpForm> {
  double _scaledWidth(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    return w > 500 ? w / 2 : w;
  }

  @override
  Widget build(BuildContext context) {
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
                    fit: BoxFit.contain,
                    colorFilter: const ColorFilter.mode(Colors.transparent, BlendMode.dst),
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
                  controller: null,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    border: const OutlineInputBorder(),
                    labelText: 'enter your email ...',
                    // No errorText — validation is silent
                  ),
                ),
              ),

              Padding(
                padding: const EdgeInsets.fromLTRB(23, 0, 23, 4),
                child: TextField(
                  controller: null,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    border: const OutlineInputBorder(),
                    labelText: 'enter your password ...',
                  ),
                ),
              ),

              Padding(
                padding: const EdgeInsets.fromLTRB(23, 0, 23, 4),
                child: TextField(
                  controller: null,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    border: const OutlineInputBorder(),
                    labelText: 'confirm your password ...',
                    // No errorText — validation is silent
                  ),
                ),
              ),

              Padding(
                padding: const EdgeInsets.fromLTRB(23, 0, 23, 4),
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: const Text('back to sign in'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
