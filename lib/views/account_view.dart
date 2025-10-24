import 'package:flutter/material.dart';
import '../utils/storage.dart';
import '../models/user_account.dart';

class AccountView extends StatefulWidget {
  final VoidCallback? onSignedIn; // <-- added
  const AccountView({super.key, this.onSignedIn});

  @override
  State<AccountView> createState() => _AccountViewState();
}

class _AccountViewState extends State<AccountView> {
  UserAccount? currentUser;

  bool isRegister = false;

  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl  = TextEditingController();

  final _oldPassCtrl = TextEditingController();
  final _newPassCtrl = TextEditingController();
  final _newPass2Ctrl = TextEditingController();

  final _authFormKey = GlobalKey<FormState>();
  final _changeFormKey = GlobalKey<FormState>();

  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
  }

  Future<void> _loadCurrentUser() async {
    final user = await Storage.getCurrentUser();
    setState(() => currentUser = user);
  }

  void _toggleMode() => setState(() => isRegister = !isRegister);

  Future<void> _signOut() async {
    setState(() => _busy = true);
    await Storage.setCurrentUser(null);
    setState(() {
      _busy = false;
      currentUser = null;
    });
    if (mounted) _snack('Signed out.');
  }

  Future<void> _submitAuth() async {
    if (!_authFormKey.currentState!.validate()) return;
    setState(() => _busy = true);

    final uname = _usernameCtrl.text.trim();
    final pass  = _passwordCtrl.text;

    try {
      if (isRegister) {
        if (_confirmCtrl.text != pass) {
          setState(() => _busy = false);
          _snack('Passwords do not match.');
          return;
        }
        final user = await Storage.registerUser(username: uname, password: pass);
        setState(() => currentUser = user);
        _clearAuthFields();
        _snack('Account created. Signed in as ${user.username}.');
        widget.onSignedIn?.call(); // <-- notify gate
      } else {
        final user = await Storage.authenticate(username: uname, password: pass);
        if (user == null) {
          _snack('Invalid username or password.');
        } else {
          setState(() => currentUser = user);
          _clearAuthFields();
          _snack('Welcome back, ${user.username}!');
          widget.onSignedIn?.call(); // <-- notify gate
        }
      }
    } catch (e) {
      _snack(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _submitChangePassword() async {
    if (currentUser == null) return;
    if (!_changeFormKey.currentState!.validate()) return;

    final oldP = _oldPassCtrl.text;
    final newP = _newPassCtrl.text;
    if (newP != _newPass2Ctrl.text) {
      _snack('New passwords do not match.');
      return;
    }

    setState(() => _busy = true);
    final ok = await Storage.changePassword(
      userId: currentUser!.id,
      oldPassword: oldP,
      newPassword: newP,
    );
    setState(() => _busy = false);

    if (ok) {
      _clearChangeFields();
      _snack('Password updated.');
    } else {
      _snack('Old password incorrect.');
    }
  }

  void _clearAuthFields() {
    _usernameCtrl.clear();
    _passwordCtrl.clear();
    _confirmCtrl.clear();
  }

  void _clearChangeFields() {
    _oldPassCtrl.clear();
    _newPassCtrl.clear();
    _newPass2Ctrl.clear();
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    _oldPassCtrl.dispose();
    _newPassCtrl.dispose();
    _newPass2Ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final signedIn = currentUser != null;

    return Scaffold(
      appBar: AppBar(title: const Text('Account')),
      body: AbsorbPointer(
        absorbing: _busy,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (!signedIn) _buildAuthCard(),
            if (signedIn) _buildProfileCard(currentUser!),
            if (signedIn) const SizedBox(height: 16),
            if (signedIn) _buildChangePasswordCard(),
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

  Widget _buildAuthCard() { /* unchanged UI; same as before except _submitAuth calls onSignedIn */ 
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
                    validator: (v) => (v == null || v.isEmpty)
                        ? 'Confirm your password'
                        : null,
                  ),
                ],
                const SizedBox(height: 16),
                ElevatedButton(onPressed: _submitAuth, child: Text(isRegister ? 'Create Account' : 'Sign In')),
                TextButton(onPressed: _toggleMode, child: Text(isRegister ? 'Already have an account? Sign in' : 'No account? Create one')),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProfileCard(UserAccount user) {
  return Card(
    color: Colors.grey[900],
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Signed In',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.orangeAccent, // brighter header
            ),
          ),
          const SizedBox(height: 12),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.person, color: Colors.orangeAccent),
            title: Text(
              user.username,
              style: const TextStyle(
                fontSize: 18,
                color: Colors.white, // <-- brighter username
                fontWeight: FontWeight.bold,
              ),
            ),
            subtitle: Text(
              'User ID: ${user.id.substring(0, 12)}...',
              style: const TextStyle(
                fontSize: 13,
                color: Colors.white70, // <-- softer gray for contrast
              ),
            ),
          ),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            onPressed: _signOut,
            icon: const Icon(Icons.logout, color: Colors.white),
            label: const Text(
              'Sign Out',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent, // stays red, higher contrast
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}


  Widget _buildChangePasswordCard() { /* unchanged */ 
    return _busyOverlay(
      child: Card(
        color: Colors.grey[900],
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _changeFormKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Change Password', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _oldPassCtrl,
                  decoration: const InputDecoration(labelText: 'Old Password', border: OutlineInputBorder()),
                  obscureText: true,
                  validator: (v) => (v == null || v.isEmpty) ? 'Enter your old password' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _newPassCtrl,
                  decoration: const InputDecoration(labelText: 'New Password', border: OutlineInputBorder()),
                  obscureText: true,
                  validator: (v) => (v == null || v.isEmpty) ? 'Enter a new password' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _newPass2Ctrl,
                  decoration: const InputDecoration(labelText: 'Confirm New Password', border: OutlineInputBorder()),
                  obscureText: true,
                  validator: (v) => (v == null || v.isEmpty) ? 'Confirm the new password' : null,
                ),
                const SizedBox(height: 16),
                ElevatedButton(onPressed: _submitChangePassword, child: const Text('Update Password')),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
