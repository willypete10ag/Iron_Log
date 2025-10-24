import 'package:flutter/material.dart';
import '../services/auth_api.dart';
import '../utils/session.dart';

class AccountView extends StatefulWidget {
  final VoidCallback? onSignedIn; // AuthGate uses this
  const AccountView({super.key, this.onSignedIn});

  @override
  State<AccountView> createState() => _AccountViewState();
}

class _AccountViewState extends State<AccountView> {
  final _api = AuthApi();

  // UI state
  bool isRegister = false;
  bool _busy = false;
  Map<String, dynamic>? _remoteUser;

  // auth controllers
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl  = TextEditingController();
  final _authFormKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _loadMeIfToken();
  }

  Future<void> _loadMeIfToken() async {
    setState(() => _busy = true);
    try {
      final token = await Session.token;
      if (token != null) {
        final me = await _api.me();
        setState(() => _remoteUser = me);
      }
    } catch (_) {
      // ignore; likely no token or expired
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _submitAuth() async {
    if (!_authFormKey.currentState!.validate()) return;
    final u = _usernameCtrl.text.trim();
    final p = _passwordCtrl.text;
    setState(() => _busy = true);
    try {
      if (isRegister) {
        if (_confirmCtrl.text != p) {
          _snack('Passwords do not match.');
          return;
        }
        await _api.register(u, p);
      } else {
        await _api.login(u, p);
      }
      final me = await _api.me();
      setState(() {
        _remoteUser = me;
        _usernameCtrl.clear();
        _passwordCtrl.clear();
        _confirmCtrl.clear();
      });
      _snack(isRegister ? 'Account created. Signed in as ${me['username']}' : 'Welcome back, ${me['username']}!');
      widget.onSignedIn?.call();
    } catch (e) {
      _snack(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _signOut() async {
    setState(() => _busy = true);
    await Session.clear();
    setState(() => _remoteUser = null);
    _snack('Signed out.');
    if (mounted) setState(() => _busy = false);
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final signedIn = _remoteUser != null;

    return Scaffold(
      appBar: AppBar(title: const Text('Account')),
      body: AbsorbPointer(
        absorbing: _busy,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (!signedIn) _buildAuthCard(),
            if (signedIn) _buildProfileCard(_remoteUser!),
          ],
        ),
      ),
    );
  }

  Widget _busyOverlay({required Widget child}) {
    return Stack(
      children: [
        child,
        if (_busy)
          Positioned.fill(
            child: Container(
              color: Colors.black45,
              alignment: Alignment.center,
              child: const CircularProgressIndicator(),
            ),
          ),
      ],
    );
  }

  Widget _buildAuthCard() {
    return _busyOverlay(
      child: Card(
        color: Colors.grey[900],
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _authFormKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(isRegister ? 'Create Account' : 'Sign In',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _usernameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Username',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter a username' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _passwordCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Password',
                    border: OutlineInputBorder(),
                  ),
                  obscureText: true,
                  validator: (v) => (v == null || v.isEmpty) ? 'Enter a password' : null,
                ),
                if (isRegister) ...[
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _confirmCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Confirm Password',
                      border: OutlineInputBorder(),
                    ),
                    obscureText: true,
                    validator: (v) => (v == null || v.isEmpty) ? 'Confirm password' : null,
                  ),
                ],
                const SizedBox(height: 16),
                ElevatedButton(onPressed: _submitAuth, child: Text(isRegister ? 'Create Account' : 'Sign In')),
                TextButton(
                  onPressed: () => setState(() => isRegister = !isRegister),
                  child: Text(isRegister ? 'Already have an account? Sign in' : 'No account? Create one'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProfileCard(Map<String, dynamic> user) {
    return Card(
      color: Colors.grey[900],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Signed In',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.orangeAccent)),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.person, color: Colors.orangeAccent),
              title: Text(
                user['username'] ?? '',
                style: const TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                'User ID: ${(user['id'] ?? '').toString().substring(0, 12)}...',
                style: const TextStyle(fontSize: 13, color: Colors.white70),
              ),
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: _signOut,
              icon: const Icon(Icons.logout, color: Colors.white),
              label: const Text('Sign Out', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
