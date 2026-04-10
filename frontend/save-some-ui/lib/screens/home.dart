import 'package:flutter/material.dart';

import 'package:flutter_svg/flutter_svg.dart';

import 'package:save_some_ui/screens/products.dart';
import 'package:save_some_ui/screens/account.dart';
import 'package:save_some_ui/screens/history.dart';
import 'package:save_some_ui/screens/maps.dart';

// import 'package:save_some_ui/forms/signin.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  static const List<Widget> _pages = <Widget>[
    ProductScreen(),
    MapsScreen(),
    HomeScreen(),
    HistoryScreen(),
    AccountScreen(),
  ];

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  void onItemTapped(int idx) {
    setState(() {
      _selectedIndex = idx;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          children: [
            Padding(
                padding: const EdgeInsets.fromLTRB(23, 0, 23, 4),
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: const Text('back to sign in'),
                ),
              ),
            BottomNavigationBar(
              unselectedItemColor: Colors.grey,
              selectedItemColor: Colors.black,
              currentIndex: _selectedIndex,
              backgroundColor: Colors.black,
              onTap: onItemTapped,
              items: [
                BottomNavigationBarItem(
                  icon: Icon(Icons.shop),
                  label: 'Products',
                ),

                BottomNavigationBarItem(
                  icon: Icon(Icons.location_on),
                  label: 'Maps',
                ),

                BottomNavigationBarItem(
                  icon: SvgPicture.asset(
                    'assets/wallet-logo.svg',
                    height: 30,
                    width: 30,
                    placeholderBuilder: (_) => const SizedBox(
                      height: 25,
                      width: 25,
                      child: CircularProgressIndicator(strokeWidth: 3),
                    ),
                  ),
                  label: 'Home',
                ),

                BottomNavigationBarItem(
                  icon: Icon(Icons.folder),
                  label: 'History',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.account_circle),
                  label: 'Account',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
