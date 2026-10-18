import 'package:flutter/material.dart';

class ConfigurationErrorScreen extends StatelessWidget {
  const ConfigurationErrorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(28),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 520),
            child: Card(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.settings_suggest_outlined, size: 32),
                    SizedBox(height: 16),
                    Text(
                      'Supabase configuration required',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Provide the project publishable key when launching the app '
                      'with --dart-define=SUPABASE_PUBLISHABLE_KEY=your_key.',
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
