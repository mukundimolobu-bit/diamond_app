import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthUser;

import '../auth/auth_gateway.dart';
import 'auth_screen.dart';
import 'dashboard_screen.dart';

class AuthenticatedAppShell extends StatefulWidget {
  const AuthenticatedAppShell({required this.gateway, this.client, super.key});

  final AuthGateway gateway;
  final SupabaseClient? client;

  @override
  State<AuthenticatedAppShell> createState() => _AuthenticatedAppShellState();
}

class _AuthenticatedAppShellState extends State<AuthenticatedAppShell> {
  late AuthUser? _user;
  late final StreamSubscription<AuthUser?> _subscription;
  bool _signingOut = false;
  String? _notice;

  @override
  void initState() {
    super.initState();
    _user = _verifiedUser(widget.gateway.currentUser);
    _subscription = widget.gateway.authStateChanges.listen(_handleAuthChange);
  }

  AuthUser? _verifiedUser(AuthUser? user) =>
      user != null && user.isEmailConfirmed ? user : null;

  void _handleAuthChange(AuthUser? user) {
    if (!mounted) return;
    setState(() {
      _user = _verifiedUser(user);
      if (user != null && !user.isEmailConfirmed) {
        _notice = 'Please verify your email before accessing Diamond Rewards.';
      } else if (user != null) {
        _notice = null;
      }
    });
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }

  Future<void> _signOut() async {
    setState(() => _signingOut = true);
    try {
      await widget.gateway.signOut();
    } catch (error) {
      if (mounted) setState(() => _notice = 'Unable to sign out: $error');
    } finally {
      if (mounted) setState(() => _signingOut = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_user == null) return AuthScreen(gateway: widget.gateway);
    return DashboardScreen(
      user: _user!,
      client: widget.client,
      signingOut: _signingOut,
      signOutNotice: _notice,
      onSignOut: _signOut,
    );
  }
}
