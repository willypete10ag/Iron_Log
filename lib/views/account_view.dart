import 'package:flutter/material.dart';
import '../services/auth_api.dart';
import '../utils/session.dart';
import '../utils/toast.dart';

class AccountView extends StatefulWidget {
  final VoidCallback? onSignedIn;   // AuthGate uses this to flip into the app
  final VoidCallback? onSignedOut;  // so AuthGate can react to logout

  const AccountView({
    super.key,
    this.onSignedIn,
    this.onSignedOut,
  });

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
  final _confirmCtrl = TextEditingController();
  final _authFormKey = GlobalKey<FormState>();

  // visibility toggles
  bool _hidePassword = true;
  bool _hideConfirm = true;

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
      // probably no/expired token; silently ignore
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
        // validate confirm matches
        if (_confirmCtrl.text != p) {
          if (mounted) {
            showIronToast(
              context,
              'Passwords do not match.',
              leading: const Icon(Icons.error),
            );
            setState(() => _busy = false); // FIX: ensure busy resets
          }
          return;
        }

        await _api.register(u, p);

        if (mounted) {
          showIronToast(
            context,
            'Account created.',
            leading: const Icon(Icons.check_circle),
          );
        }
      } else {
        // normal login
        await _api.login(u, p);

        if (mounted) {
          showIronToast(
            context,
            'Welcome back!',
            leading: const Icon(Icons.login),
          );
        }
      }

      // pull /me, save it, update UI
      final me = await _api.me();

      setState(() {
        _remoteUser = me;
        _usernameCtrl.clear();
        _passwordCtrl.clear();
        _confirmCtrl.clear();
      });

      // notify AuthGate
      widget.onSignedIn?.call();
    } catch (e) {
      if (mounted) {
        showIronToast(
          context,
          e.toString().replaceFirst('Exception: ', ''),
          leading: const Icon(Icons.warning),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _signOut() async {
    setState(() => _busy = true);

    await Session.clear();

    setState(() {
      _remoteUser = null;
    });

    if (mounted) {
      showIronToast(
        context,
        'Signed out.',
        leading: const Icon(Icons.logout),
      );
    }

    // Tell AuthGate you’re out. This flips the app back to login.
    widget.onSignedOut?.call();

    if (mounted) setState(() => _busy = false);
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
      // No inner AppBar; main.dart provides the top AppBar
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
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return _busyOverlay(
      child: Card(
        color: cs.surface.withOpacity(0.35),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _authFormKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  isRegister ? 'Create Account' : 'Sign In',
                  style: tt.titleMedium?.copyWith(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: cs.secondary,
                  ),
                ),

                const SizedBox(height: 16),

                TextFormField(
                  controller: _usernameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Username',
                    border: OutlineInputBorder(),
                  ),
                  autofillHints: const [AutofillHints.username],
                  textInputAction: TextInputAction.next,
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Enter a username' : null,
                ),

                const SizedBox(height: 12),

                TextFormField(
                  controller: _passwordCtrl,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(_hidePassword ? Icons.visibility : Icons.visibility_off),
                      onPressed: () => setState(() => _hidePassword = !_hidePassword),
                      tooltip: _hidePassword ? 'Show password' : 'Hide password',
                    ),
                  ),
                  obscureText: _hidePassword,
                  autofillHints: const [AutofillHints.password],
                  textInputAction: isRegister ? TextInputAction.next : TextInputAction.done,
                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'Enter a password' : null,
                ),

                if (isRegister) ...[
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _confirmCtrl,
                    decoration: InputDecoration(
                      labelText: 'Confirm Password',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: Icon(_hideConfirm ? Icons.visibility : Icons.visibility_off),
                        onPressed: () => setState(() => _hideConfirm = !_hideConfirm),
                        tooltip: _hideConfirm ? 'Show password' : 'Hide password',
                      ),
                    ),
                    obscureText: _hideConfirm,
                    textInputAction: TextInputAction.done,
                    validator: (v) =>
                        (v == null || v.isEmpty) ? 'Confirm password' : null,
                  ),
                ],

                const SizedBox(height: 16),

                ElevatedButton(
                  onPressed: _submitAuth,
                  child: Text(isRegister ? 'Create Account' : 'Sign In'),
                ),

                TextButton(
                  onPressed: () => setState(() => isRegister = !isRegister),
                  child: Text(
                    isRegister
                        ? 'Already have an account? Sign in'
                        : 'No account? Create one',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProfileCard(Map<String, dynamic> user) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Card(
      color: cs.surface.withOpacity(0.35),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Signed In',
              style: tt.titleMedium?.copyWith(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: cs.primary,
              ),
            ),
            const SizedBox(height: 12),

            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                backgroundColor: cs.primary,
                child: const Icon(Icons.person, color: Colors.white),
              ),
              title: Text(
                user['username'] ?? '',
                style: tt.titleMedium?.copyWith(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                'User ID: ${(user['id'] ?? '').toString().padRight(12).substring(0, 12)}...',
                style: tt.bodySmall?.copyWith(
                  color: tt.bodySmall?.color?.withOpacity(0.7),
                ),
              ),
            ),

            const SizedBox(height: 8),

            ElevatedButton.icon(
              onPressed: _signOut,
              icon: const Icon(Icons.logout),
              label: const Text('Sign Out'),
              style: ElevatedButton.styleFrom(
                backgroundColor: cs.error,
                foregroundColor: Colors.white,
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
