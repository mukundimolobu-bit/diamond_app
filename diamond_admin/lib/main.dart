import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'admin_app.dart';

const _supabaseUrl = 'https://wqncystqpxtvqzgstixi.supabase.co';
const _publishableKey = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (_publishableKey.trim().isEmpty) {
    runApp(const AdminConfigurationApp());
    return;
  }

  try {
    await Supabase.initialize(
      url: _supabaseUrl,
      publishableKey: _publishableKey,
    );
    runApp(
      AdminApp(
        authGateway: SupabaseAdminAuthGateway(Supabase.instance.client),
        roleRepository: SupabaseAdminRoleRepository(Supabase.instance.client),
      ),
    );
  } catch (_) {
    runApp(const AdminConfigurationApp(initializationFailed: true));
  }
}

class AdminConfigurationApp extends StatelessWidget {
  const AdminConfigurationApp({this.initializationFailed = false, super.key});

  final bool initializationFailed;

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Diamond Rewards Admin',
    theme: _adminTheme,
    home: Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            initializationFailed
                ? 'Supabase could not be initialized. Check the app configuration and network, then restart.'
                : 'Supabase configuration required. Run with --dart-define=SUPABASE_PUBLISHABLE_KEY=your_key.',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    ),
  );
}

final _adminTheme = ThemeData(
  colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF6543C5)),
  useMaterial3: true,
  scaffoldBackgroundColor: const Color(0xFFFAF9FF),
);
