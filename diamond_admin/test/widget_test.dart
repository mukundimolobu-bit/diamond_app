import 'dart:async';

import 'package:flutter/material.dart' show Key;
import 'package:flutter_test/flutter_test.dart';
import 'package:diamond_admin/admin_app.dart';

class _FakeAuthGateway implements AdminAuthGateway {
  final _events = StreamController<AdminUser?>.broadcast();
  AdminUser? user;
  Object? signInError;

  @override
  AdminUser? get currentUser => user;

  @override
  Stream<AdminUser?> get authChanges => _events.stream;

  @override
  Future<void> signIn({required String email, required String password}) async {
    if (signInError != null) throw signInError!;
  }

  @override
  Future<void> signOut() async {
    user = null;
    _events.add(null);
  }

  Future<void> dispose() => _events.close();
}

class _FakeRoleRepository implements AdminRoleRepository {
  _FakeRoleRepository(this.role);

  final String? role;
  Object? error;

  @override
  Future<String?> roleFor(String userId) async {
    if (error != null) throw error!;
    return role;
  }
}

AdminUser _user() => const AdminUser(id: 'user-1', email: 'admin@example.com');

Future<void> _pump(
  WidgetTester tester, {
  required _FakeAuthGateway auth,
  required _FakeRoleRepository roles,
}) async {
  await tester.pumpWidget(AdminApp(authGateway: auth, roleRepository: roles));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('signed-out visitor sees the sign-in screen', (tester) async {
    final auth = _FakeAuthGateway();
    await _pump(tester, auth: auth, roles: _FakeRoleRepository('admin'));

    expect(find.text('Admin sign in'), findsOneWidget);
    expect(find.byKey(const Key('adminEmailField')), findsOneWidget);
    expect(find.text('Admin workspace'), findsNothing);

    await auth.dispose();
  });

  testWidgets('admin role can access the admin shell', (tester) async {
    final auth = _FakeAuthGateway()..user = _user();
    await _pump(tester, auth: auth, roles: _FakeRoleRepository('admin'));

    expect(find.text('Admin workspace'), findsOneWidget);
    expect(find.text('Task management'), findsOneWidget);
    expect(find.text('Coming soon'), findsOneWidget);
    expect(find.byKey(const Key('adminSignOutButton')), findsOneWidget);

    await auth.dispose();
  });

  testWidgets('super_admin role can access the admin shell', (tester) async {
    final auth = _FakeAuthGateway()..user = _user();
    await _pump(tester, auth: auth, roles: _FakeRoleRepository('super_admin'));

    expect(find.text('Admin workspace'), findsOneWidget);
    expect(find.text('This account does not have admin access.'), findsNothing);

    await auth.dispose();
  });

  testWidgets('standard user role is denied admin access', (tester) async {
    final auth = _FakeAuthGateway()..user = _user();
    await _pump(tester, auth: auth, roles: _FakeRoleRepository('user'));

    expect(
      find.text('This account does not have admin access.'),
      findsOneWidget,
    );
    expect(find.text('Admin workspace'), findsNothing);

    await auth.dispose();
  });

  testWidgets('missing profile role denies access', (tester) async {
    final auth = _FakeAuthGateway()..user = _user();
    await _pump(tester, auth: auth, roles: _FakeRoleRepository(null));

    expect(
      find.text('This account does not have admin access.'),
      findsOneWidget,
    );
    expect(find.text('Admin workspace'), findsNothing);

    await auth.dispose();
  });

  testWidgets('role lookup error safely denies access', (tester) async {
    final auth = _FakeAuthGateway()..user = _user();
    final roles = _FakeRoleRepository(null)..error = Exception('network');
    await _pump(tester, auth: auth, roles: roles);

    expect(
      find.text('Access could not be verified. Admin access is denied.'),
      findsOneWidget,
    );
    expect(find.text('Admin workspace'), findsNothing);

    await auth.dispose();
  });

  testWidgets('invalid sign-in credentials show a safe error', (tester) async {
    final auth = _FakeAuthGateway()..signInError = Exception('invalid login');
    await _pump(tester, auth: auth, roles: _FakeRoleRepository('admin'));
    await tester.enterText(
      find.byKey(const Key('adminEmailField')),
      'member@example.com',
    );
    await tester.enterText(
      find.byKey(const Key('adminPasswordField')),
      'wrong-password',
    );
    await tester.tap(find.byKey(const Key('adminSignInButton')));
    await tester.pumpAndSettle();

    expect(
      find.text('Sign-in failed. Check your details and connection.'),
      findsOneWidget,
    );
    expect(find.text('Admin workspace'), findsNothing);

    await auth.dispose();
  });
}
