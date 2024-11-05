import 'package:flutter/material.dart';
import 'hjem.dart';
import 'kort.dart';
import 'indberet.dart';
import 'timer.dart';
import 'settings.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Map with User Location',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MainScreen(),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  // Initialize the event log here to share across the app
  List<String> _eventLog = [];

  final List<Widget> _pages;

  _MainScreenState() : _pages = [
    const HjemPage(), // HjemPage will need a way to update _eventLog
    const KortPage(),
    // Placeholder for IndberetPage to pass event log
    const IndberetPage(eventLog: []), // Temporary until HjemPage is updated
    const TimerPage(),
    const SettingsPage(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;

      // If navigating to IndberetPage, update it with the current event log
      if (index == 2) { // Index of IndberetPage
        _pages[2] = IndberetPage(eventLog: _eventLog); // Update IndberetPage with event log
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Hjem',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.map),
            label: 'Kort',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.report),
            label: 'Indberet',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.timer),
            label: 'Timer',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.deepPurple,
        onTap: _onItemTapped,
      ),
    );
  }
}
