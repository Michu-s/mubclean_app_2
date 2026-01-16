import 'package:flutter/material.dart';
import 'customer_home.dart';
import 'customer_requests_screens.dart';
import 'customer_support_screen.dart';
import 'customer_menu_screen.dart';

class CustomerMainScreen extends StatefulWidget {
  const CustomerMainScreen({super.key});

  @override
  State<CustomerMainScreen> createState() => _CustomerMainScreenState();
}

class _CustomerMainScreenState extends State<CustomerMainScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const CustomerHomeScreen(),
    const CustomerRequestsScreen(),
    const CustomerSupportScreen(),
    const CustomerMenuScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: Theme(
        data: Theme.of(context).copyWith(
          canvasColor: Colors.black, // Background color of the bottom bar
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
          backgroundColor: Colors.black,
          selectedItemColor: Colors.white,
          unselectedItemColor: Colors.grey,
          type: BottomNavigationBarType.fixed,
          showSelectedLabels: true,
          showUnselectedLabels: true,
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Inicio'),
            BottomNavigationBarItem(
              icon: Icon(Icons.history),
              label: 'Historial', // "Amigos" in ref, but "Historial" requested
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.help_outline),
              label: 'Ayuda',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person),
              label: 'Perfil', // "Perfil" in ref, mapping to Menu
            ),
          ],
        ),
      ),
    );
  }
}
