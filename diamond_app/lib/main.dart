import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth/auth_gateway.dart';
import 'screens/app_shell.dart';
import 'screens/configuration_error_screen.dart';

const _supabaseUrl = 'https://wqncystqpxtvqzgstixi.supabase.co';
const _publishableKey = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final hasPublishableKey = _publishableKey.trim().isNotEmpty;
  if (hasPublishableKey) {
    await Supabase.initialize(
      url: _supabaseUrl,
      publishableKey: _publishableKey,
    );
  }

  runApp(
    DiamondRewardsApp(
      configurationError: !hasPublishableKey,
      authGateway: hasPublishableKey
          ? SupabaseAuthGateway(Supabase.instance.client)
          : null,
      client: hasPublishableKey ? Supabase.instance.client : null,
    ),
  );
}

class DiamondRewardsApp extends StatelessWidget {
  const DiamondRewardsApp({
    required this.configurationError,
    this.authGateway,
    this.client,
    super.key,
  });

  final bool configurationError;
  final AuthGateway? authGateway;
  final SupabaseClient? client;

  @override
  Widget build(BuildContext context) {
    const purple = Color(0xFF6543C5);
    return MaterialApp(
      title: 'Diamond Rewards',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: purple),
        scaffoldBackgroundColor: const Color(0xFFFAF9FF),
        useMaterial3: true,
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFFF8F6FC),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFECE8F4)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: purple, width: 1.5),
          ),
        ),
      ),
      home: configurationError
          ? const ConfigurationErrorScreen()
          : AuthenticatedAppShell(
              gateway:
                  authGateway ?? SupabaseAuthGateway(Supabase.instance.client),
              client:
                  client ??
                  (authGateway == null ? Supabase.instance.client : null),
            ),
    );
  }
}
