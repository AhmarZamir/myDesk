import 'package:flutter/material.dart';
import '../services/auth_service.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _auth = AuthService();
  bool _signUp = false;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (_signUp) {
        await _auth.signUp(fullName: _name.text, email: _email.text, password: _password.text);
      } else {
        await _auth.signIn(email: _email.text, password: _password.text);
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString().replaceFirst('AuthException(message: ', '').replaceAll(')', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary, borderRadius: BorderRadius.circular(14)),
                              child: const Icon(Icons.dashboard_customize, color: Colors.white),
                            ),
                            const SizedBox(width: 10),
                            const Text('myDesk', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          _signUp ? 'Create your personal workspace' : 'Welcome back to your workspace',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.black54),
                        ),
                        const SizedBox(height: 28),
                        if (_signUp) ...[
                          TextFormField(
                            controller: _name,
                            decoration: const InputDecoration(labelText: 'Full name', prefixIcon: Icon(Icons.person_outline), border: OutlineInputBorder()),
                            validator: (v) => (v == null || v.trim().length < 2) ? 'Enter your name' : null,
                          ),
                          const SizedBox(height: 14),
                        ],
                        TextFormField(
                          controller: _email,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.mail_outline), border: OutlineInputBorder()),
                          validator: (v) => (v == null || !v.contains('@')) ? 'Enter a valid email' : null,
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _password,
                          obscureText: true,
                          decoration: const InputDecoration(labelText: 'Password', prefixIcon: Icon(Icons.lock_outline), border: OutlineInputBorder()),
                          validator: (v) => (v == null || v.length < 6) ? 'Use at least 6 characters' : null,
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 12),
                          Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                        ],
                        const SizedBox(height: 20),
                        FilledButton(
                          onPressed: _loading ? null : _submit,
                          style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                          child: _loading
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                              : Text(_signUp ? 'Create account' : 'Sign in'),
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: _loading ? null : () => setState(() { _signUp = !_signUp; _error = null; }),
                          child: Text(_signUp ? 'Already have an account? Sign in' : 'New to myDesk? Create account'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
