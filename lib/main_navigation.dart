import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'features/home/dashboard_page.dart';
import 'features/chat/chat_page.dart';
import 'features/finance/recap_page.dart';

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _selectedIndex = 0;

  final List<Widget> _pages = [
    const DashboardPage(), // Halaman Utama dengan Grafik
    const ChatPage(), // Fitur Chat AI & Chat-to-Record
    const RecapPage(), // Fitur Laporan Detail
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_selectedIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 20)],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 15.0, vertical: 8),
            child: BottomNavigationBar(
              currentIndex: _selectedIndex,
              onTap: (index) => setState(() => _selectedIndex = index),
              backgroundColor: Colors.white,
              elevation: 0,
              selectedItemColor: Colors.indigoAccent,
              unselectedItemColor: Colors.grey,
              showUnselectedLabels: true,
              type: BottomNavigationBarType.fixed,
              items: const [
                BottomNavigationBarItem(
                  icon: Icon(LucideIcons.layoutDashboard),
                  label: 'Home',
                ),
                BottomNavigationBarItem(
                  icon: Icon(LucideIcons.messageSquare),
                  label: 'Chat AI',
                ),
                BottomNavigationBarItem(
                  icon: Icon(LucideIcons.pieChart),
                  label: 'Laporan',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
