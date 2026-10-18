import 'dart:async';

import 'package:flutter/material.dart'
    show ChoiceChip, CircularProgressIndicator, Key, OutlinedButton, ValueKey;
// The Supabase client accepts this package's HTTP client for a local mock.
// ignore: depend_on_referenced_packages
import 'package:http/http.dart' show Response;
// ignore: depend_on_referenced_packages
import 'package:http/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:diamond_app/auth/auth_gateway.dart';
import 'package:diamond_app/main.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show AuthClientOptions, SupabaseClient;

class _FakeAuthGateway implements AuthGateway {
  final _events = StreamController<AuthUser?>.broadcast();
  AuthUser? _user;
  bool requireVerification = true;
  String? resetEmail;

  @override
  AuthUser? get currentUser => _user;

  @override
  Stream<AuthUser?> get authStateChanges => _events.stream;

  @override
  Future<SignUpResult> signUp({
    required String fullName,
    required String email,
    required String password,
  }) async {
    final user = AuthUser(
      id: 'new-user',
      email: email,
      isEmailConfirmed: !requireVerification,
    );
    if (!requireVerification) {
      _user = user;
      _events.add(user);
    }
    return SignUpResult(user: user, hasSession: !requireVerification);
  }

  @override
  Future<void> signIn({required String email, required String password}) async {
    _user = AuthUser(id: 'signed-in', email: email, isEmailConfirmed: true);
    _events.add(_user);
  }

  @override
  Future<bool> signInWithGoogle({required String redirectTo}) async => true;

  @override
  Future<void> sendPasswordReset(String email) async {
    resetEmail = email;
  }

  @override
  Future<void> signOut() async {
    _user = null;
    _events.add(null);
  }

  Future<void> dispose() => _events.close();
}

_FakeAuthGateway _signedInGateway() => _FakeAuthGateway()
  .._user = const AuthUser(
    id: 'existing',
    email: 'member@example.com',
    isEmailConfirmed: true,
  );

void main() {
  testWidgets('shows setup guidance when Supabase key is missing', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const DiamondRewardsApp(configurationError: true));

    expect(find.text('Supabase configuration required'), findsOneWidget);
  });

  testWidgets('shows sign-in and native Google setup explanation', (
    WidgetTester tester,
  ) async {
    final gateway = _FakeAuthGateway();
    await tester.pumpWidget(
      DiamondRewardsApp(configurationError: false, authGateway: gateway),
    );

    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.byKey(const Key('emailField')), findsOneWidget);
    expect(find.text('Continue with Google'), findsOneWidget);
    expect(
      find.textContaining('Google sign-in is unavailable'),
      findsOneWidget,
    );
    expect(
      tester
          .widget<OutlinedButton>(find.byKey(const Key('googleSignInButton')))
          .onPressed,
      isNull,
    );
    await gateway.dispose();
  });

  testWidgets(
    'sign-up collects profile details and requires email verification',
    (WidgetTester tester) async {
      final gateway = _FakeAuthGateway();
      await tester.pumpWidget(
        DiamondRewardsApp(configurationError: false, authGateway: gateway),
      );
      await tester.tap(find.byKey(const Key('signUpTab')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('fullNameField')), findsOneWidget);
      expect(find.byKey(const Key('emailField')), findsOneWidget);
      expect(find.byKey(const Key('passwordField')), findsOneWidget);
      expect(find.byKey(const Key('confirmPasswordField')), findsOneWidget);

      await tester.enterText(
        find.byKey(const Key('fullNameField')),
        'Alex Diamond',
      );
      await tester.enterText(
        find.byKey(const Key('emailField')),
        'alex@example.com',
      );
      await tester.enterText(
        find.byKey(const Key('passwordField')),
        'password123',
      );
      await tester.enterText(
        find.byKey(const Key('confirmPasswordField')),
        'password123',
      );
      await tester.ensureVisible(find.byKey(const Key('authSubmitButton')));
      await tester.tap(find.byKey(const Key('authSubmitButton')));
      await tester.pumpAndSettle();

      expect(find.textContaining('verify your email'), findsOneWidget);
      expect(find.text('Welcome back'), findsOneWidget);
      expect(find.text('You’re signed in'), findsNothing);
      await gateway.dispose();
    },
  );

  testWidgets('password reset sends email through the auth gateway', (
    WidgetTester tester,
  ) async {
    final gateway = _FakeAuthGateway();
    await tester.pumpWidget(
      DiamondRewardsApp(configurationError: false, authGateway: gateway),
    );
    await tester.tap(find.text('Forgot password?'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('emailField')),
      'alex@example.com',
    );
    await tester.tap(find.byKey(const Key('authSubmitButton')));
    await tester.pumpAndSettle();

    expect(gateway.resetEmail, 'alex@example.com');
    expect(
      find.textContaining('password reset link has been sent'),
      findsOneWidget,
    );
    await gateway.dispose();
  });

  testWidgets('does not restore an unverified existing session', (
    WidgetTester tester,
  ) async {
    final gateway = _FakeAuthGateway()
      .._user = const AuthUser(
        id: 'unverified',
        email: 'pending@example.com',
        isEmailConfirmed: false,
      );
    await tester.pumpWidget(
      DiamondRewardsApp(configurationError: false, authGateway: gateway),
    );

    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('You’re signed in'), findsNothing);
    await gateway.dispose();
  });

  testWidgets(
    'restores a verified session and signs out through auth changes',
    (WidgetTester tester) async {
      final gateway = _FakeAuthGateway()
        .._user = const AuthUser(
          id: 'existing',
          email: 'member@example.com',
          isEmailConfirmed: true,
        );
      await tester.pumpWidget(
        DiamondRewardsApp(configurationError: false, authGateway: gateway),
      );

      expect(find.textContaining('Welcome back'), findsOneWidget);
      await tester.tap(find.text('Profile'));
      await tester.pumpAndSettle();
      expect(find.text('member@example.com'), findsOneWidget);
      await tester.tap(find.text('Sign out'));
      await tester.pumpAndSettle();

      expect(find.text('Welcome back'), findsOneWidget);
      await gateway.dispose();
    },
  );

  testWidgets('configured Supabase client starts dashboard account queries', (
    WidgetTester tester,
  ) async {
    final requests = <Uri>[];
    final httpClient = MockClient((request) async {
      requests.add(request.url);
      final body = request.url.path.endsWith('/profiles')
          ? '{"display_name":"Database User","referral_code":"DB123"}'
          : '{"diamonds":123,"gummies":5}';
      return Response(body, 200, headers: {'content-type': 'application/json'});
    });
    final client = SupabaseClient(
      'https://supabase.test',
      'test-publishable-key',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
      httpClient: httpClient,
    );
    final gateway = _FakeAuthGateway()
      .._user = const AuthUser(
        id: 'existing',
        email: 'member@example.com',
        isEmailConfirmed: true,
      );

    await tester.pumpWidget(
      DiamondRewardsApp(
        configurationError: false,
        authGateway: gateway,
        client: client,
      ),
    );
    await tester.pumpAndSettle();

    expect(
      requests.map((uri) => uri.path),
      containsAll(['/rest/v1/profiles', '/rest/v1/reward_balances']),
    );
    expect(
      requests.any(
        (uri) =>
            uri.path.endsWith('/profiles') &&
            uri.queryParameters['id'] == 'eq.existing',
      ),
      isTrue,
    );
    expect(
      requests.any(
        (uri) =>
            uri.path.endsWith('/reward_balances') &&
            uri.queryParameters['user_id'] == 'eq.existing',
      ),
      isTrue,
    );
    httpClient.close();
    await gateway.dispose();
  });

  testWidgets('Videos tabs select five labelled design placeholders', (
    WidgetTester tester,
  ) async {
    final gateway = _FakeAuthGateway()
      .._user = const AuthUser(
        id: 'existing',
        email: 'member@example.com',
        isEmailConfirmed: true,
      );
    await tester.pumpWidget(
      DiamondRewardsApp(configurationError: false, authGateway: gateway),
    );

    await tester.tap(find.text('Videos').last);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('videosDesignPreview')), findsOneWidget);
    expect(find.text('Watch Videos'), findsOneWidget);
    expect(
      find.text('Choose an ad network to explore its videos.'),
      findsOneWidget,
    );
    expect(find.text('Showing 5 videos for Network A'), findsOneWidget);
    expect(
      find.textContaining('Network A · design placeholder'),
      findsNWidgets(5),
    );
    expect(find.text('Preview only · not playable'), findsNWidgets(5));

    for (var networkIndex = 0; networkIndex < 4; networkIndex++) {
      final tabKey = ValueKey('videoNetworkTab$networkIndex');
      if (networkIndex > 0) {
        await tester.tap(find.byKey(tabKey));
        await tester.pumpAndSettle();
      }
      expect(tester.widget<ChoiceChip>(find.byKey(tabKey)).selected, isTrue);
      expect(
        find.text(
          'Showing 5 videos for Network ${String.fromCharCode(65 + networkIndex)}',
        ),
        findsOneWidget,
      );
      for (var videoIndex = 0; videoIndex < 5; videoIndex++) {
        expect(find.byKey(ValueKey('videoCard$videoIndex')), findsOneWidget);
      }
      expect(
        find.textContaining(
          'Network ${String.fromCharCode(65 + networkIndex)} · design placeholder',
        ),
        findsNWidgets(5),
      );
    }

    expect(find.textContaining('not connected to ad networks'), findsOneWidget);
    expect(find.textContaining('no reward is earned'), findsOneWidget);

    await gateway.dispose();
  });

  testWidgets('Surveys shows the coming-soon state', (
    WidgetTester tester,
  ) async {
    final gateway = _FakeAuthGateway()
      .._user = const AuthUser(
        id: 'existing',
        email: 'member@example.com',
        isEmailConfirmed: true,
      );
    await tester.pumpWidget(
      DiamondRewardsApp(configurationError: false, authGateway: gateway),
    );

    await tester.tap(find.text('Surveys').last);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('surveysUnavailableState')), findsOneWidget);
    expect(find.text('SURVEYS COMING SOON'), findsOneWidget);
    expect(find.text('Surveys coming soon'), findsOneWidget);
    expect(
      find.text('Discover survey opportunities as they become available.'),
      findsOneWidget,
    );
    expect(find.textContaining('No survey provider'), findsOneWidget);

    await gateway.dispose();
  });

  testWidgets('Tasks shows loading while the catalogue request is pending', (
    WidgetTester tester,
  ) async {
    final response = Completer<Response>();
    final requests = <Uri>[];
    final httpClient = MockClient((request) async {
      requests.add(request.url);
      if (request.url.path.endsWith('/tasks')) {
        return response.future.then(
          (value) => Response(
            value.body,
            value.statusCode,
            headers: value.headers,
            request: request,
          ),
        );
      }
      return Response(
        '[]',
        200,
        headers: {'content-type': 'application/json'},
        request: request,
      );
    });
    final client = SupabaseClient(
      'https://supabase.test',
      'test-publishable-key',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
      httpClient: httpClient,
    );
    final gateway = _signedInGateway();

    await tester.pumpWidget(
      DiamondRewardsApp(
        configurationError: false,
        authGateway: gateway,
        client: client,
      ),
    );
    await tester.tap(find.text('Tasks').last);
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(requests.any((uri) => uri.path.endsWith('/tasks')), isTrue);
    response.complete(
      Response('[]', 200, headers: {'content-type': 'application/json'}),
    );
    await tester.pumpAndSettle();
    httpClient.close();
    await gateway.dispose();
  });

  testWidgets('Tasks lists real catalogue results and filters active rows', (
    WidgetTester tester,
  ) async {
    final requests = <Uri>[];
    final httpClient = MockClient((request) async {
      requests.add(request.url);
      if (request.url.path.endsWith('/tasks')) {
        return Response(
          '[{"id":"task-1","title":"Read guide","description":"Read the published guide.","image_url":null,"estimated_minutes":12,"diamond_reward":45,"external_url":"https://example.com/guide","is_active":true,"sort_order":1}]',
          200,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      }
      return Response(
        '[]',
        200,
        headers: {'content-type': 'application/json'},
        request: request,
      );
    });
    final client = SupabaseClient(
      'https://supabase.test',
      'test-publishable-key',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
      httpClient: httpClient,
    );
    final gateway = _signedInGateway();

    await tester.pumpWidget(
      DiamondRewardsApp(
        configurationError: false,
        authGateway: gateway,
        client: client,
      ),
    );
    await tester.tap(find.text('Tasks').last);
    await tester.pumpAndSettle();

    expect(find.text('Read guide'), findsOneWidget);
    expect(find.text('Read the published guide.'), findsOneWidget);
    expect(find.text('12 min'), findsOneWidget);
    expect(find.text('45 diamonds'), findsOneWidget);
    expect(
      find.textContaining('Task completion and reward verification'),
      findsOneWidget,
    );
    final taskRequest = requests.firstWhere(
      (uri) => uri.path.endsWith('/tasks'),
    );
    expect(taskRequest.queryParameters['is_active'], 'eq.true');
    expect(
      taskRequest.queryParameters['order'],
      'sort_order.asc.nullslast,id.asc.nullslast',
    );
    expect(taskRequest.queryParameters['select'], contains('diamond_reward'));
    expect(taskRequest.queryParameters['select'], isNot(contains('metadata')));

    await tester.tap(find.byKey(const Key('taskCard-task-1')));
    await tester.pumpAndSettle();
    expect(find.text('External task link'), findsOneWidget);
    expect(find.text('https://example.com/guide'), findsOneWidget);
    expect(
      find.text('Task completion and verification are coming soon.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Back to tasks'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('tasksCatalogue')), findsOneWidget);

    httpClient.close();
    await gateway.dispose();
  });

  testWidgets('Tasks shows a friendly empty state for no active rows', (
    WidgetTester tester,
  ) async {
    final httpClient = MockClient(
      (request) async => Response(
        '[]',
        200,
        headers: {'content-type': 'application/json'},
        request: request,
      ),
    );
    final client = SupabaseClient(
      'https://supabase.test',
      'test-publishable-key',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
      httpClient: httpClient,
    );
    final gateway = _signedInGateway();

    await tester.pumpWidget(
      DiamondRewardsApp(
        configurationError: false,
        authGateway: gateway,
        client: client,
      ),
    );
    await tester.tap(find.text('Tasks').last);
    await tester.pumpAndSettle();

    expect(find.text('No tasks available right now'), findsOneWidget);
    expect(
      find.text('Please check back later for published tasks.'),
      findsOneWidget,
    );
    httpClient.close();
    await gateway.dispose();
  });

  testWidgets('Tasks shows API errors and provides retry', (
    WidgetTester tester,
  ) async {
    var taskRequests = 0;
    final httpClient = MockClient((request) async {
      if (request.url.path.endsWith('/tasks')) {
        taskRequests++;
        return Response(
          '{"message":"permission denied for table tasks"}',
          403,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      }
      return Response(
        '[]',
        200,
        headers: {'content-type': 'application/json'},
        request: request,
      );
    });
    final client = SupabaseClient(
      'https://supabase.test',
      'test-publishable-key',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
      httpClient: httpClient,
    );
    final gateway = _signedInGateway();

    await tester.pumpWidget(
      DiamondRewardsApp(
        configurationError: false,
        authGateway: gateway,
        client: client,
      ),
    );
    await tester.tap(find.text('Tasks').last);
    await tester.pumpAndSettle();

    expect(find.text('Task catalogue unavailable'), findsOneWidget);
    expect(
      find.textContaining('permission denied for table tasks'),
      findsOneWidget,
    );
    expect(find.text('Retry'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(taskRequests, 2);
    httpClient.close();
    await gateway.dispose();
  });

  testWidgets('Tasks handles nullable fields and hides invalid external URLs', (
    WidgetTester tester,
  ) async {
    final httpClient = MockClient((request) async {
      if (request.url.path.endsWith('/tasks')) {
        return Response(
          '[{"id":"task-null","title":"Optional details","description":null,"image_url":null,"estimated_minutes":null,"diamond_reward":0,"external_url":"javascript:alert(1)","is_active":true,"sort_order":1}]',
          200,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      }
      return Response(
        '[]',
        200,
        headers: {'content-type': 'application/json'},
        request: request,
      );
    });
    final client = SupabaseClient(
      'https://supabase.test',
      'test-publishable-key',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
      httpClient: httpClient,
    );
    final gateway = _signedInGateway();

    await tester.pumpWidget(
      DiamondRewardsApp(
        configurationError: false,
        authGateway: gateway,
        client: client,
      ),
    );
    await tester.tap(find.text('Tasks').last);
    await tester.pumpAndSettle();
    expect(find.text('Optional details'), findsOneWidget);
    expect(find.text('0 diamonds'), findsOneWidget);
    expect(find.textContaining(' min'), findsNothing);
    await tester.tap(find.byKey(const Key('taskCard-task-null')));
    await tester.pumpAndSettle();
    expect(find.text('External task link'), findsNothing);
    expect(find.text('javascript:alert(1)'), findsNothing);
    httpClient.close();
    await gateway.dispose();
  });
}
