import 'package:flutter/material.dart';
import 'views/lifts_view.dart';
import 'views/history_view.dart';
import 'views/account_view.dart';
import 'views/lift_progress_chart_view.dart';
import 'utils/session.dart';
import 'services/auth_api.dart';
import 'services/sync_service.dart';

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
      ),
      home: const AuthGate(), // start with AuthGate
      debugShowCheckedModeBanner: false,
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _loading = true;
  bool _signedIn = false;
  final _api = AuthApi();
  final _sync = SyncService();

  @override
  void initState() {
    super.initState();
    _checkRemoteSession();
  }

  Future<void> _checkRemoteSession() async {
    final token = await Session.token;
    if (token == null) {
      setState(() {
        _signedIn = false;
        _loading = false;
      });
      return;
    }

    try {
      await _api.me();

      // 🔄 pull latest server data whenever token is still valid
      try {
        await _sync.pullFromServer();
      } catch (e) {
        debugPrint('pullFromServer on resume error: $e');
      }

      setState(() {
        _signedIn = true;
        _loading = false;
      });
    } catch (_) {
      await Session.clear();
      setState(() {
        _signedIn = false;
        _loading = false;
      });
    }
  }

  Future<void> _handleSignedIn() async {
    // Just logged in or registered — token now valid
    try {
      await _sync.pullFromServer();
    } catch (e) {
      debugPrint('pullFromServer error: $e');
      // If server has nothing yet, seed it
      try {
        await _sync.pushToServer();
      } catch (e2) {
        debugPrint('pushToServer error: $e2');
      }
    }

    setState(() {
      _signedIn = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (!_signedIn) {
      return AccountView(onSignedIn: _handleSignedIn);
    }

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
    AccountView(),
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
          BottomNavigationBarItem(
              icon: Icon(Icons.fitness_center), label: 'Lifts'),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: 'History'),
          BottomNavigationBarItem(
              icon: Icon(Icons.show_chart), label: 'Progress'),
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
