import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../auth/auth_gateway.dart';

enum _AuthMode { signIn, signUp, forgotPassword }

class AuthScreen extends StatefulWidget {
  const AuthScreen({required this.gateway, super.key});

  final AuthGateway gateway;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  _AuthMode _mode = _AuthMode.signIn;
  bool _busy = false;
  bool _obscurePassword = true;
  String? _message;
  bool _messageIsError = false;

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      final parameters = Uri.base.queryParameters;
      if (parameters.containsKey('error') ||
          parameters.containsKey('error_code')) {
        final error = (parameters['error'] ?? parameters['error_code'] ?? '')
            .toLowerCase();
        _message = error == 'access_denied'
            ? 'Google sign-in was cancelled. You can try again whenever you’re ready.'
            : 'Google sign-in could not be completed. Please try again.';
        _messageIsError = true;
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  void _setMode(_AuthMode mode) {
    setState(() {
      _mode = mode;
      _message = null;
      _messageIsError = false;
    });
    _formKey.currentState?.reset();
  }

  String? _required(String? value, String label) {
    if (value == null || value.trim().isEmpty) return 'Enter your $label.';
    return null;
  }

  String? _validateEmail(String? value) {
    final requiredError = _required(value, 'email address');
    if (requiredError != null) return requiredError;
    if (!value!.contains('@') || value.trim().endsWith('@')) {
      return 'Enter a valid email address.';
    }
    return null;
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final email = _emailController.text.trim();
      if (_mode == _AuthMode.signUp) {
        final result = await widget.gateway.signUp(
          fullName: _nameController.text.trim(),
          email: email,
          password: _passwordController.text,
        );
        if (result.hasSession && result.user?.isEmailConfirmed == true) {
          if (mounted) {
            setState(() {
              _message = 'Your account is ready.';
              _messageIsError = false;
            });
          }
        } else if (mounted) {
          setState(() {
            _mode = _AuthMode.signIn;
            _message =
                'Account created. Check your inbox and verify your email '
                'before signing in.';
            _messageIsError = false;
          });
        }
      } else if (_mode == _AuthMode.signIn) {
        await widget.gateway.signIn(
          email: email,
          password: _passwordController.text,
        );
        final user = widget.gateway.currentUser;
        if (user == null || !user.isEmailConfirmed) {
          if (mounted) {
            setState(() {
              _message =
                  'Please verify your email before signing in. Check your '
                  'inbox for the confirmation link.';
              _messageIsError = true;
            });
          }
        }
      } else {
        await widget.gateway.sendPasswordReset(email);
        if (mounted) {
          setState(() {
            _message =
                'If an account exists for this email, a password reset '
                'link has been sent.';
            _messageIsError = false;
          });
        }
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _message = _friendlyError(error);
          _messageIsError = true;
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() {
      _busy = true;
      _message = null;
      _messageIsError = false;
    });
    try {
      final launched = await widget.gateway.signInWithGoogle(
        redirectTo: Uri.base
            .replace(queryParameters: const <String, String>{}, fragment: '')
            .toString(),
      );
      if (!launched && mounted) {
        setState(() {
          _message =
              'Google sign-in did not start. It may have been cancelled. '
              'Please try again.';
          _messageIsError = true;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _message = _friendlyError(error);
          _messageIsError = true;
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _friendlyError(Object error) {
    final raw = error.toString();
    if (raw.toLowerCase().contains('email not confirmed')) {
      return 'Please verify your email before signing in. Check your inbox for '
          'the confirmation link.';
    }
    return raw
        .replaceFirst('AuthException: ', '')
        .replaceFirst('Exception: ', '');
  }

  @override
  Widget build(BuildContext context) {
    final isSignUp = _mode == _AuthMode.signUp;
    final isForgot = _mode == _AuthMode.forgotPassword;
    final title = isForgot
        ? 'Reset your password'
        : isSignUp
        ? 'Create your account'
        : 'Welcome back';
    final subtitle = isForgot
        ? 'We’ll email you a secure reset link.'
        : isSignUp
        ? 'Join Diamond Rewards and enjoy what’s ahead.'
        : 'Sign in to continue to Diamond Rewards.';

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 30),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _BrandHeader(),
                  const SizedBox(height: 24),
                  Card(
                    elevation: 0,
                    color: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(26),
                      side: const BorderSide(color: Color(0xFFECE8F4)),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              color: Color(0xFF241A3B),
                              fontSize: 25,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            subtitle,
                            style: const TextStyle(
                              color: Color(0xFF746D82),
                              height: 1.45,
                            ),
                          ),
                          if (!isForgot) ...[
                            const SizedBox(height: 22),
                            _ModeSelector(
                              selected: _mode,
                              onSelected: _setMode,
                            ),
                          ],
                          const SizedBox(height: 20),
                          Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                if (isSignUp) ...[
                                  _label('Full name'),
                                  TextFormField(
                                    key: const Key('fullNameField'),
                                    controller: _nameController,
                                    textCapitalization:
                                        TextCapitalization.words,
                                    autofillHints: const [AutofillHints.name],
                                    validator: (value) =>
                                        _required(value, 'name'),
                                    decoration: const InputDecoration(
                                      hintText: 'Your full name',
                                      prefixIcon: Icon(Icons.person_outline),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                ],
                                _label('Email address'),
                                TextFormField(
                                  key: const Key('emailField'),
                                  controller: _emailController,
                                  keyboardType: TextInputType.emailAddress,
                                  textInputAction: TextInputAction.next,
                                  autofillHints: const [AutofillHints.email],
                                  validator: _validateEmail,
                                  decoration: const InputDecoration(
                                    hintText: 'you@example.com',
                                    prefixIcon: Icon(Icons.mail_outline),
                                  ),
                                ),
                                if (!isForgot) ...[
                                  const SizedBox(height: 16),
                                  _label('Password'),
                                  TextFormField(
                                    key: const Key('passwordField'),
                                    controller: _passwordController,
                                    obscureText: _obscurePassword,
                                    textInputAction: isSignUp
                                        ? TextInputAction.next
                                        : TextInputAction.done,
                                    autofillHints: isSignUp
                                        ? const [AutofillHints.newPassword]
                                        : const [AutofillHints.password],
                                    validator: (value) {
                                      final error = _required(
                                        value,
                                        'password',
                                      );
                                      if (error != null) return error;
                                      if (isSignUp && value!.length < 8) {
                                        return 'Use at least 8 characters.';
                                      }
                                      return null;
                                    },
                                    decoration: InputDecoration(
                                      hintText: 'Enter your password',
                                      prefixIcon: const Icon(
                                        Icons.lock_outline,
                                      ),
                                      suffixIcon: IconButton(
                                        tooltip: _obscurePassword
                                            ? 'Show password'
                                            : 'Hide password',
                                        onPressed: () => setState(() {
                                          _obscurePassword = !_obscurePassword;
                                        }),
                                        icon: Icon(
                                          _obscurePassword
                                              ? Icons.visibility_outlined
                                              : Icons.visibility_off_outlined,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                                if (isSignUp) ...[
                                  const SizedBox(height: 16),
                                  _label('Confirm password'),
                                  TextFormField(
                                    key: const Key('confirmPasswordField'),
                                    controller: _confirmController,
                                    obscureText: true,
                                    textInputAction: TextInputAction.done,
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return 'Confirm your password.';
                                      }
                                      if (value != _passwordController.text) {
                                        return 'Passwords do not match.';
                                      }
                                      return null;
                                    },
                                    decoration: const InputDecoration(
                                      hintText: 'Re-enter your password',
                                      prefixIcon: Icon(Icons.lock_outline),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          if (_mode == _AuthMode.signIn) ...[
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: _busy
                                    ? null
                                    : () => _setMode(_AuthMode.forgotPassword),
                                child: const Text('Forgot password?'),
                              ),
                            ),
                          ] else
                            const SizedBox(height: 12),
                          if (_message != null) ...[
                            _MessageBanner(
                              message: _message!,
                              isError: _messageIsError,
                            ),
                            const SizedBox(height: 14),
                          ],
                          SizedBox(
                            height: 52,
                            child: FilledButton(
                              key: const Key('authSubmitButton'),
                              onPressed: _busy ? null : _submit,
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFF6543C5),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(15),
                                ),
                              ),
                              child: _busy
                                  ? const SizedBox(
                                      width: 21,
                                      height: 21,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : Text(
                                      isForgot
                                          ? 'Send reset link'
                                          : isSignUp
                                          ? 'Create account'
                                          : 'Sign in',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 16,
                                      ),
                                    ),
                            ),
                          ),
                          if (isForgot) ...[
                            const SizedBox(height: 8),
                            TextButton(
                              onPressed: _busy
                                  ? null
                                  : () => _setMode(_AuthMode.signIn),
                              child: const Text('Back to sign in'),
                            ),
                          ],
                          if (!isForgot) ...[
                            const SizedBox(height: 20),
                            const Row(
                              children: [
                                Expanded(child: Divider()),
                                Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 12),
                                  child: Text(
                                    'OR',
                                    style: TextStyle(
                                      color: Color(0xFF8C849A),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                Expanded(child: Divider()),
                              ],
                            ),
                            const SizedBox(height: 16),
                            OutlinedButton.icon(
                              key: const Key('googleSignInButton'),
                              onPressed: _busy || !kIsWeb
                                  ? null
                                  : _signInWithGoogle,
                              icon: _busy
                                  ? const SizedBox.square(
                                      dimension: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.g_mobiledata, size: 26),
                              label: const Text('Continue with Google'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF4B4358),
                                disabledForegroundColor: const Color(
                                  0xFF6F687D,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(15),
                                ),
                                side: const BorderSide(
                                  color: Color(0xFFE8E3F0),
                                ),
                              ),
                            ),
                            const SizedBox(height: 9),
                            Text(
                              kIsWeb
                                  ? 'You’ll return to this page after Google authorization.'
                                  : _nativeGoogleSignInMessage(),
                              key: const Key('googleSignInPlatformNote'),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Color(0xFF817A90),
                                fontSize: 12,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Your account is protected by secure email verification.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Color(0xFF847D91), fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 7),
    child: Text(
      text,
      style: const TextStyle(
        color: Color(0xFF362C4A),
        fontWeight: FontWeight.w700,
        fontSize: 13,
      ),
    ),
  );

  String _nativeGoogleSignInMessage() {
    return switch (defaultTargetPlatform) {
      TargetPlatform.android =>
        'Google sign-in is unavailable on Android until native redirect '
            'configuration is added.',
      TargetPlatform.iOS =>
        'Google sign-in is unavailable on iOS until native redirect '
            'configuration is added.',
      _ =>
        'Google sign-in is available in the web app. Native app setup '
            'has not been configured.',
    };
  }
}

class _BrandHeader extends StatelessWidget {
  const _BrandHeader();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 58,
          height: 58,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF6543C5), Color(0xFFE65A9B)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(19),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF6543C5).withValues(alpha: 0.2),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: const Icon(
            Icons.diamond_outlined,
            color: Colors.white,
            size: 31,
          ),
        ),
        const SizedBox(height: 13),
        const Text(
          'DIAMOND REWARDS',
          style: TextStyle(
            color: Color(0xFF6543C5),
            fontWeight: FontWeight.w800,
            letterSpacing: 2.2,
            fontSize: 13,
          ),
        ),
      ],
    );
  }
}

class _ModeSelector extends StatelessWidget {
  const _ModeSelector({required this.selected, required this.onSelected});

  final _AuthMode selected;
  final ValueChanged<_AuthMode> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F1F9),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Row(
        children: [
          _tab('Sign in', _AuthMode.signIn),
          _tab('Sign up', _AuthMode.signUp),
        ],
      ),
    );
  }

  Widget _tab(String label, _AuthMode mode) {
    final active = selected == mode;
    return Expanded(
      child: TextButton(
        key: Key(mode == _AuthMode.signIn ? 'signInTab' : 'signUpTab'),
        onPressed: () => onSelected(mode),
        style: TextButton.styleFrom(
          backgroundColor: active ? Colors.white : Colors.transparent,
          foregroundColor: active
              ? const Color(0xFF6543C5)
              : const Color(0xFF817A90),
          elevation: active ? 1 : 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
      ),
    );
  }
}

class _MessageBanner extends StatelessWidget {
  const _MessageBanner({required this.message, required this.isError});

  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final foreground = isError
        ? const Color(0xFF9E3151)
        : const Color(0xFF375F48);
    final background = isError
        ? const Color(0xFFFFEEF2)
        : const Color(0xFFEEF8F1);
    return Container(
      key: const Key('authMessage'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(message, style: TextStyle(color: foreground, height: 1.4)),
    );
  }
}
