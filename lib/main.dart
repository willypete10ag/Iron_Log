import 'package:flutter/material.dart';
import 'views/lifts_view.dart';
import 'views/history_view.dart';
import 'views/account_view.dart';
import 'views/lift_progress_chart_view.dart';
import 'utils/storage.dart';
import 'models/user_account.dart';

void main() {
  runApp(const IronLogApp());
}

class IronLogApp extends StatelessWidget {
  const IronLogApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'IronLog',
      theme: ThemeData.dark().copyWith(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.orangeAccent),
        scaffoldBackgroundColor: Colors.black,
        textTheme: const TextTheme(bodyMedium: TextStyle(color: Colors.white)),
      ),
      home: const AuthGate(), // <-- gate instead of IronLogHome
    );
  }
}

/// Shows AccountView until a user is signed in; then shows IronLogHome.
/// This prevents any "global" data usage.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  UserAccount? _user;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _checkUser();
  }

  Future<void> _checkUser() async {
    final user = await Storage.getCurrentUser();
    setState(() {
      _user = user;
      _loading = false;
    });
  }

  void _handleSignedIn() async {
    final user = await Storage.getCurrentUser();
    setState(() => _user = user);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_user == null) {
      // Force sign-in: show AccountView only
      return AccountView(onSignedIn: _handleSignedIn);
    }

    // Signed in: show the main tabbed app
    return const IronLogHome();
  }
}

class IronLogHome extends StatefulWidget {
  const IronLogHome({super.key});

  @override
  State<IronLogHome> createState() => _IronLogHomeState();
}

class _IronLogHomeState extends State<IronLogHome> {
  int _selectedIndex = 0;

  final List<Widget> _pages = const [
    LiftsView(),
    HistoryView(),
    LiftProgressChartView(),
    AccountView(), // still accessible for change password / sign-out
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.fitness_center), label: 'Lifts'),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: 'History'),
          BottomNavigationBarItem(icon: Icon(Icons.show_chart), label: 'Progress'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Account'),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.orangeAccent,
        unselectedItemColor: Colors.white70,
        onTap: _onItemTapped,
      ),
    );
  }
}
