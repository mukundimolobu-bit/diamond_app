import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminUser {
  const AdminUser({required this.id, required this.email});

  final String id;
  final String email;
}

abstract interface class AdminAuthGateway {
  AdminUser? get currentUser;
  Stream<AdminUser?> get authChanges;
  Future<void> signIn({required String email, required String password});
  Future<void> signOut();
}

class SupabaseAdminAuthGateway implements AdminAuthGateway {
  SupabaseAdminAuthGateway(this._client);

  final SupabaseClient _client;

  AdminUser? _mapUser(User? user) =>
      user == null ? null : AdminUser(id: user.id, email: user.email ?? '');

  @override
  AdminUser? get currentUser => _mapUser(_client.auth.currentUser);

  @override
  Stream<AdminUser?> get authChanges => _client.auth.onAuthStateChange.map(
    (event) => _mapUser(event.session?.user),
  );

  @override
  Future<void> signIn({required String email, required String password}) async {
    await _client.auth.signInWithPassword(email: email, password: password);
  }

  @override
  Future<void> signOut() => _client.auth.signOut();
}

abstract interface class AdminRoleRepository {
  Future<String?> roleFor(String userId);
}

class SupabaseAdminRoleRepository implements AdminRoleRepository {
  SupabaseAdminRoleRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<String?> roleFor(String userId) async {
    final profile = await _client
        .from('profiles')
        .select('role')
        .eq('id', userId)
        .maybeSingle();
    return profile?['role']?.toString();
  }
}

class AdminApp extends StatelessWidget {
  const AdminApp({
    required this.authGateway,
    required this.roleRepository,
    super.key,
  });

  final AdminAuthGateway authGateway;
  final AdminRoleRepository roleRepository;

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Diamond Rewards Admin',
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF6543C5)),
      useMaterial3: true,
      scaffoldBackgroundColor: const Color(0xFFFAF9FF),
    ),
    home: _AuthGate(authGateway: authGateway, roleRepository: roleRepository),
  );
}

class _AuthGate extends StatelessWidget {
  const _AuthGate({required this.authGateway, required this.roleRepository});

  final AdminAuthGateway authGateway;
  final AdminRoleRepository roleRepository;

  @override
  Widget build(BuildContext context) => StreamBuilder<AdminUser?>(
    stream: authGateway.authChanges,
    initialData: authGateway.currentUser,
    builder: (context, snapshot) {
      final user = snapshot.data;
      if (user == null) return _SignInScreen(authGateway: authGateway);
      return _RoleGate(
        key: ValueKey(user.id),
        user: user,
        authGateway: authGateway,
        roleRepository: roleRepository,
      );
    },
  );
}

class _SignInScreen extends StatefulWidget {
  const _SignInScreen({required this.authGateway});

  final AdminAuthGateway authGateway;

  @override
  State<_SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<_SignInScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await widget.authGateway.signIn(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Sign-in failed. Check your details and connection.',
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Diamond Rewards Admin')),
    body: Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Admin sign in',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      key: const Key('adminEmailField'),
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.username],
                      decoration: const InputDecoration(labelText: 'Email'),
                      validator: (value) =>
                          value == null || !value.contains('@')
                          ? 'Enter a valid email address'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      key: const Key('adminPasswordField'),
                      controller: _passwordController,
                      obscureText: true,
                      autofillHints: const [AutofillHints.password],
                      decoration: const InputDecoration(labelText: 'Password'),
                      validator: (value) => value == null || value.isEmpty
                          ? 'Enter your password'
                          : null,
                      onFieldSubmitted: (_) => _loading ? null : _submit(),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        _error!,
                        key: const Key('adminSignInError'),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    FilledButton(
                      key: const Key('adminSignInButton'),
                      onPressed: _loading ? null : _submit,
                      child: _loading
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Sign in'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _RoleGate extends StatefulWidget {
  const _RoleGate({
    required this.user,
    required this.authGateway,
    required this.roleRepository,
    super.key,
  });

  final AdminUser user;
  final AdminAuthGateway authGateway;
  final AdminRoleRepository roleRepository;

  @override
  State<_RoleGate> createState() => _RoleGateState();
}

class _RoleGateState extends State<_RoleGate> {
  late Future<String?> _roleFuture;

  @override
  void initState() {
    super.initState();
    _roleFuture = widget.roleRepository.roleFor(widget.user.id);
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<String?>(
    future: _roleFuture,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      final role = snapshot.data;
      if (snapshot.hasError || (role != 'admin' && role != 'super_admin')) {
        return _AccessDeniedScreen(
          authGateway: widget.authGateway,
          lookupFailed: snapshot.hasError,
        );
      }
      return _AdminShell(user: widget.user, authGateway: widget.authGateway);
    },
  );
}

class _AccessDeniedScreen extends StatelessWidget {
  const _AccessDeniedScreen({
    required this.authGateway,
    required this.lookupFailed,
  });

  final AdminAuthGateway authGateway;
  final bool lookupFailed;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Diamond Rewards Admin')),
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_outline, size: 42),
            const SizedBox(height: 12),
            Text(
              lookupFailed
                  ? 'Access could not be verified. Admin access is denied.'
                  : 'This account does not have admin access.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: authGateway.signOut,
              child: const Text('Sign out'),
            ),
          ],
        ),
      ),
    ),
  );
}

class _AdminShell extends StatelessWidget {
  const _AdminShell({required this.user, required this.authGateway});

  final AdminUser user;
  final AdminAuthGateway authGateway;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Diamond Rewards Admin'),
      actions: [
        IconButton(
          key: const Key('adminSignOutButton'),
          tooltip: 'Sign out',
          onPressed: authGateway.signOut,
          icon: const Icon(Icons.logout),
        ),
      ],
    ),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Card(
          margin: const EdgeInsets.all(24),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Admin workspace',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 6),
                Text(user.email),
                const SizedBox(height: 24),
                const ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.checklist_outlined),
                  title: Text('Task management'),
                  subtitle: Text('Coming soon'),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
