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

/// Centralized brand colors (from your logo)
class IronColors {
  static const background = Color(0xFF3B3541); // charcoal
  static const primary = Color(0xFFF57C00); // orange
  static const secondary = Color(0xFF2EC6F5); // cyan
  static const onDarkText = Color(0xFFF5F5F5);
}

final ThemeData ironLogTheme = ThemeData(
  brightness: Brightness.dark,
  scaffoldBackgroundColor: IronColors.background,
  primaryColor: IronColors.primary,
  colorScheme: const ColorScheme.dark(
    primary: IronColors.primary,
    secondary: IronColors.secondary,
    surface: IronColors.background,
    onPrimary: Colors.white,
    onSecondary: Colors.white,
  ),
  appBarTheme: const AppBarTheme(
    backgroundColor: IronColors.background,
    elevation: 0,
    titleTextStyle: TextStyle(
      color: IronColors.secondary,
      fontWeight: FontWeight.w700,
      fontSize: 20,
      letterSpacing: 0.3,
    ),
    iconTheme: IconThemeData(color: IronColors.secondary),
  ),
  floatingActionButtonTheme: const FloatingActionButtonThemeData(
    backgroundColor: IronColors.primary,
    foregroundColor: Colors.white,
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: IronColors.primary,
      foregroundColor: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
  ),
  snackBarTheme: const SnackBarThemeData(
    backgroundColor: IronColors.primary,
    contentTextStyle: TextStyle(color: Colors.white),
    behavior: SnackBarBehavior.floating,
  ),
  // ⬇️ Removed tabBarTheme to avoid SDK type mismatch
  bottomNavigationBarTheme: const BottomNavigationBarThemeData(
    backgroundColor: IronColors.background,
    selectedItemColor: IronColors.secondary,
    unselectedItemColor: Colors.white70,
    type: BottomNavigationBarType.fixed,
    selectedIconTheme: IconThemeData(size: 26),
    unselectedIconTheme: IconThemeData(size: 24),
  ),
  dividerColor: Colors.white10,
  textTheme: const TextTheme(
    bodyLarge: TextStyle(color: IronColors.onDarkText),
    bodyMedium: TextStyle(color: IronColors.onDarkText),
    titleMedium: TextStyle(
      color: IronColors.onDarkText,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.2,
    ),
  ),
);

class IronLogApp extends StatelessWidget {
  const IronLogApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'IronLog',
      theme: ironLogTheme,
      home: const AuthGate(),
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

      // Pull latest server data if still valid
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
    try {
      await _sync.pullFromServer();
    } catch (e) {
      debugPrint('pullFromServer error: $e');
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

  void _handleSignedOut() {
    setState(() {
      _signedIn = false;
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
      return AccountView(
        onSignedIn: _handleSignedIn,
        onSignedOut: _handleSignedOut,
      );
    }

    return IronLogHome(onSignedOut: _handleSignedOut);
  }
}

class IronLogHome extends StatefulWidget {
  final VoidCallback onSignedOut;
  const IronLogHome({super.key, required this.onSignedOut});

  @override
  State<IronLogHome> createState() => _IronLogHomeState();
}

class _IronLogHomeState extends State<IronLogHome> {
  int _selectedIndex = 0;

  late final List<Widget> _pages;
  late final List<String> _titles;

  @override
  void initState() {
    super.initState();

    _pages = [
      const LiftsView(),
      const HistoryView(),
      const LiftProgressChartView(),
      AccountView(
        onSignedIn: () {}, // no-op for this context
        onSignedOut: widget.onSignedOut,
      ),
    ];

    _titles = const [
      'Lifts',
      'History',
      'Progress',
      'Account',
    ];
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final title = _titles[_selectedIndex];

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            // App logo (ensure pubspec lists assets/images/ironlog_logo.png)
            Image.asset(
              'assets/images/ironlog_logo.png',
              height: 28,
            ),
            const SizedBox(width: 10),
            Text(title),
          ],
        ),
      ),
      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.fitness_center),
            label: 'Lifts',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history),
            label: 'History',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.show_chart),
            label: 'Progress',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Account',
          ),
        ],
        currentIndex: _selectedIndex,
        // rely on theme for colors
        onTap: _onItemTapped,
      ),
    );
  }
}
